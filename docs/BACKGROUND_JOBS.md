# Background Jobs Authorization Guide

This guide covers authorization in background jobs (Sidekiq, Resque, DelayedJob, etc.) using SimpleAuthorize.

## Table of Contents

- [Overview](#overview)
- [Basic Patterns](#basic-patterns)
- [Sidekiq Integration](#sidekiq-integration)
- [ActiveJob Integration](#activejob-integration)
- [Security Considerations](#security-considerations)
- [Common Patterns](#common-patterns)
- [Testing](#testing)

## Overview

Background jobs run outside the request-response cycle, so there's no `current_user` or controller context. You need to explicitly pass user and authorization information to jobs.

### Key Principles

1. **Pass User ID, Not User Object** - Serialize user ID, reload in job
2. **Authorize in the Job** - Don't assume authorization from the calling code
3. **Handle Authorization Failures** - Jobs should gracefully handle denied actions
4. **Audit Job Authorization** - Log who initiated background actions

## Basic Patterns

### Pattern 1: Pass User ID and Record ID

```ruby
# app/jobs/publish_post_job.rb
class PublishPostJob < ApplicationJob
  queue_as :default

  def perform(user_id, post_id)
    user = User.find(user_id)
    post = Post.find(post_id)

    # Create policy and authorize
    policy = PostPolicy.new(user, post)

    unless policy.publish?
      Rails.logger.warn("User #{user_id} not authorized to publish post #{post_id}")
      return  # Or raise error, send notification, etc.
    end

    post.update!(published: true)
    NotificationMailer.post_published(post).deliver_later
  end
end

# In controller
def publish
  @post = Post.find(params[:id])
  authorize @post, :publish?  # Authorize in controller too

  PublishPostJob.perform_later(current_user.id, @post.id)
  redirect_to @post, notice: "Post will be published shortly"
end
```

### Pattern 2: Policy Check Helper

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  class NotAuthorizedError < StandardError; end

  protected

  def authorize(user, record, action)
    policy_class = "#{record.class}Policy".constantize
    policy = policy_class.new(user, record)

    unless policy.public_send(action)
      raise NotAuthorizedError, "User #{user.id} cannot #{action} #{record.class} #{record.id}"
    end
  end
end

# app/jobs/update_post_job.rb
class UpdatePostJob < ApplicationJob
  def perform(user_id, post_id, attributes)
    user = User.find(user_id)
    post = Post.find(post_id)

    authorize(user, post, :update?)

    post.update!(attributes)
  end
end
```

### Pattern 3: Store Authorization Context

```ruby
# app/jobs/bulk_operation_job.rb
class BulkOperationJob < ApplicationJob
  def perform(user_id, operation, record_ids)
    user = User.find(user_id)
    policy_class = "#{operation[:model]}Policy".constantize

    authorized_records = []
    unauthorized_records = []

    record_ids.each do |id|
      record = operation[:model].constantize.find(id)
      policy = policy_class.new(user, record)

      if policy.public_send(operation[:action])
        authorized_records << record
      else
        unauthorized_records << id
      end
    end

    # Process authorized records
    authorized_records.each do |record|
      record.public_send(operation[:method])
    end

    # Log unauthorized attempts
    if unauthorized_records.any?
      Rails.logger.warn(
        "Bulk operation: #{unauthorized_records.count} records unauthorized for user #{user_id}"
      )
    end
  end
end
```

## Sidekiq Integration

### Basic Sidekiq Worker

```ruby
# app/workers/post_publisher_worker.rb
class PostPublisherWorker
  include Sidekiq::Worker

  def perform(user_id, post_id)
    user = User.find_by(id: user_id)
    post = Post.find_by(id: post_id)

    # Handle missing records
    unless user && post
      logger.error("PostPublisherWorker: User or Post not found")
      return
    end

    # Authorize
    policy = PostPolicy.new(user, post)
    unless policy.publish?
      logger.warn("PostPublisherWorker: User #{user_id} cannot publish Post #{post_id}")

      # Notify user
      UserMailer.unauthorized_action(user, post, :publish).deliver_now
      return
    end

    # Perform the action
    post.update!(published: true, published_by: user, published_at: Time.current)

    # Send success notification
    PostMailer.published_notification(post, user).deliver_now
  end
end

# Usage
PostPublisherWorker.perform_async(current_user.id, @post.id)
```

### Sidekiq with Retries

```ruby
class ProcessPaymentWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3

  sidekiq_retry_in do |count, exception|
    case exception
    when NotAuthorizedError
      :kill  # Don't retry authorization failures
    else
      10 * (count + 1)  # Retry other errors with backoff
    end
  end

  def perform(user_id, order_id)
    user = User.find(user_id)
    order = Order.find(order_id)

    policy = OrderPolicy.new(user, order)
    raise NotAuthorizedError unless policy.process_payment?

    PaymentProcessor.process(order)
  end
end
```

## ActiveJob Integration

### ActiveJob with Authorization

```ruby
# app/jobs/export_data_job.rb
class ExportDataJob < ApplicationJob
  queue_as :exports

  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  discard_on NotAuthorizedError  # Don't retry authorization failures

  def perform(user_id, export_params)
    user = User.find(user_id)

    # Authorize the export action
    policy = ExportPolicy.new(user, nil)
    unless policy.export_data?
      raise NotAuthorizedError, "User #{user_id} cannot export data"
    end

    # Perform export
    data = collect_data(user, export_params)
    file_path = generate_export(data)

    # Send result
    UserMailer.export_ready(user, file_path).deliver_now
  end

  private

  def collect_data(user, params)
    # Use policy scoping to ensure user only gets their data
    scope = DataPolicy::Scope.new(user, Data.all).resolve
    scope.where(params[:filters])
  end
end
```

### Job with Policy Scope

```ruby
# app/jobs/generate_report_job.rb
class GenerateReportJob < ApplicationJob
  def perform(user_id, report_type)
    user = User.find(user_id)

    # Authorize report generation
    policy = ReportPolicy.new(user, nil)
    unless policy.send("generate_#{report_type}?")
      Rails.logger.warn("User #{user_id} cannot generate #{report_type} report")
      return
    end

    # Use policy scope to get only authorized data
    posts = PostPolicy::Scope.new(user, Post.all).resolve
    comments = CommentPolicy::Scope.new(user, Comment.all).resolve

    report = ReportGenerator.generate(
      type: report_type,
      posts: posts,
      comments: comments,
      user: user
    )

    ReportMailer.send_report(user, report).deliver_now
  end
end
```

## Security Considerations

### 1. Always Re-Authorize in Jobs

```ruby
# ❌ Bad: Assuming authorization from controller
def publish
  authorize @post, :publish?  # Authorized here
  PublishPostJob.perform_later(@post.id)  # But NOT re-checked in job!
end

# ✅ Good: Re-authorize in job
class PublishPostJob < ApplicationJob
  def perform(user_id, post_id)
    user = User.find(user_id)
    post = Post.find(post_id)

    policy = PostPolicy.new(user, post)
    return unless policy.publish?  # Re-check authorization

    post.publish!
  end
end
```

### 2. Don't Serialize Sensitive Data

```ruby
# ❌ Bad: Passing sensitive data in job arguments
SomeJob.perform_later(credit_card_number, user.password)

# ✅ Good: Pass IDs, reload in job
SomeJob.perform_later(user_id, payment_method_id)
```

### 3. Handle Deleted Records

```ruby
def perform(user_id, record_id)
  user = User.find_by(id: user_id)
  record = Record.find_by(id: record_id)

  # Handle deleted records gracefully
  unless user && record
    Rails.logger.info("Job skipped: User or Record deleted")
    return
  end

  # Continue with authorization...
end
```

### 4. Audit Job Execution

```ruby
class AuditedJob < ApplicationJob
  around_perform do |job, block|
    user_id = job.arguments.first
    started_at = Time.current

    block.call

    AuditLog.create!(
      user_id: user_id,
      action: job.class.name,
      status: 'success',
      duration: Time.current - started_at
    )
  rescue => e
    AuditLog.create!(
      user_id: user_id,
      action: job.class.name,
      status: 'failed',
      error: e.message
    )
    raise
  end
end
```

## Common Patterns

### Batch Processing with Authorization

```ruby
# app/jobs/batch_update_job.rb
class BatchUpdateJob < ApplicationJob
  def perform(user_id, record_ids, updates)
    user = User.find(user_id)
    results = { updated: [], skipped: [], errors: [] }

    record_ids.each do |id|
      record = Record.find_by(id: id)

      unless record
        results[:skipped] << { id: id, reason: 'not_found' }
        next
      end

      policy = RecordPolicy.new(user, record)
      unless policy.update?
        results[:skipped] << { id: id, reason: 'unauthorized' }
        next
      end

      if record.update(updates)
        results[:updated] << id
      else
        results[:errors] << { id: id, errors: record.errors.full_messages }
      end
    end

    # Send summary email
    BatchUpdateMailer.summary(user, results).deliver_now
  end
end
```

### Scheduled Job with Authorization

```ruby
# app/jobs/cleanup_old_posts_job.rb
class CleanupOldPostsJob < ApplicationJob
  def perform
    # System job - use system/admin user
    system_user = User.find_by(role: 'system')

    old_posts = Post.where('created_at < ?', 1.year.ago)

    old_posts.find_each do |post|
      policy = PostPolicy.new(system_user, post)

      if policy.destroy?
        post.destroy
      else
        Rails.logger.warn("Cannot destroy post #{post.id} - not authorized")
      end
    end
  end
end

# config/schedule.rb (whenever gem)
every 1.day, at: '2:00 am' do
  runner "CleanupOldPostsJob.perform_later"
end
```

### Webhook Processing with Authorization

```ruby
# app/jobs/process_webhook_job.rb
class ProcessWebhookJob < ApplicationJob
  def perform(webhook_id)
    webhook = Webhook.find(webhook_id)
    user = webhook.user

    # Authorize based on webhook action
    case webhook.event_type
    when 'post.created'
      record = Post.find(webhook.data['id'])
      policy = PostPolicy.new(user, record)
      return unless policy.create?

      post.trigger_created_callbacks

    when 'post.updated'
      record = Post.find(webhook.data['id'])
      policy = PostPolicy.new(user, record)
      return unless policy.update?

      post.trigger_updated_callbacks
    end

    webhook.update!(processed: true)
  end
end
```

### Job Chaining with Authorization

```ruby
# app/jobs/publish_and_notify_job.rb
class PublishAndNotifyJob < ApplicationJob
  def perform(user_id, post_id)
    user = User.find(user_id)
    post = Post.find(post_id)

    # Authorize publish
    return unless PostPolicy.new(user, post).publish?

    post.update!(published: true)

    # Chain to notification job if user can notify
    if PostPolicy.new(user, post).notify_subscribers?
      NotifySubscribersJob.perform_later(user_id, post_id)
    end
  end
end
```

## Testing

### Testing Jobs with Authorization

```ruby
# test/jobs/publish_post_job_test.rb
require 'test_helper'

class PublishPostJobTest < ActiveJob::TestCase
  def setup
    @admin = users(:admin)
    @author = users(:author)
    @viewer = users(:viewer)
    @post = posts(:draft)
  end

  test "admin can publish post via job" do
    PublishPostJob.perform_now(@admin.id, @post.id)

    @post.reload
    assert @post.published?
  end

  test "author can publish own post via job" do
    @post.update!(user: @author)

    PublishPostJob.perform_now(@author.id, @post.id)

    @post.reload
    assert @post.published?
  end

  test "viewer cannot publish post via job" do
    PublishPostJob.perform_now(@viewer.id, @post.id)

    @post.reload
    assert_not @post.published?
  end

  test "logs unauthorized attempt" do
    assert_difference -> { Rails.logger.warnings.count }, 1 do
      PublishPostJob.perform_now(@viewer.id, @post.id)
    end
  end
end
```

### Testing with RSpec

```ruby
# spec/jobs/publish_post_job_spec.rb
require 'rails_helper'

RSpec.describe PublishPostJob, type: :job do
  let(:post) { create(:post, :draft) }

  describe '#perform' do
    context 'when user is authorized' do
      let(:user) { create(:user, :admin) }

      it 'publishes the post' do
        expect {
          described_class.perform_now(user.id, post.id)
        }.to change { post.reload.published? }.from(false).to(true)
      end

      it 'sends notification' do
        expect {
          described_class.perform_now(user.id, post.id)
        }.to have_enqueued_job(NotificationJob)
      end
    end

    context 'when user is not authorized' do
      let(:user) { create(:user, :viewer) }

      it 'does not publish the post' do
        expect {
          described_class.perform_now(user.id, post.id)
        }.not_to change { post.reload.published? }
      end

      it 'logs warning' do
        expect(Rails.logger).to receive(:warn).with(/not authorized/)
        described_class.perform_now(user.id, post.id)
      end
    end
  end
end
```

## Best Practices

1. **Always pass User ID** - Never serialize full user objects
2. **Re-authorize in jobs** - Don't trust controller authorization
3. **Handle missing records** - User or record might be deleted
4. **Log unauthorized attempts** - For security monitoring
5. **Use policy scopes** - When collecting data in jobs
6. **Don't retry authorization failures** - They won't succeed on retry
7. **Audit job execution** - Track who initiated what
8. **Test authorization** - Include unauthorized cases in tests
9. **Graceful degradation** - Handle authorization failures without crashing
10. **Use system/admin user** - For automated/scheduled jobs when appropriate

## Conclusion

Background jobs require explicit authorization since they run outside the request context. Always:
- Pass user and record IDs, not objects
- Re-check authorization within the job
- Handle authorization failures gracefully
- Log unauthorized attempts for security auditing
- Test both authorized and unauthorized scenarios

This ensures your background jobs maintain the same security posture as your controllers.
