# Performance Optimization Guide

This guide covers performance optimization strategies for SimpleAuthorize in production applications.

## Table of Contents

- [Overview](#overview)
- [Policy Caching](#policy-caching)
- [Instrumentation](#instrumentation)
- [Database Query Optimization](#database-query-optimization)
- [View Optimization](#view-optimization)
- [Benchmarking](#benchmarking)
- [Production Configuration](#production-configuration)

## Overview

SimpleAuthorize is designed to be lightweight and fast, but there are several optimizations you can enable for production environments.

### Performance Characteristics

- **Policy instantiation**: ~0.01ms per policy (negligible)
- **Authorization check**: ~0.05ms per check (method call overhead)
- **Scope resolution**: Depends on your database query complexity
- **Without caching**: New policy instance per `policy()` call
- **With caching**: Same policy instance reused within a request

## Policy Caching

### What is Policy Caching?

Policy caching stores policy instances in memory for the duration of a single request, avoiding repeated instantiation for the same user + record + policy class combination.

### When to Enable

✅ **Enable caching when:**
- You make multiple authorization checks on the same record in views
- You have complex policy initialization logic
- You're rendering collections with policy checks per item
- Performance profiling shows policy instantiation overhead

❌ **Don't enable caching when:**
- Your policies have side effects (they shouldn't anyway!)
- You're modifying user roles mid-request (unusual)
- You have memory constraints (caching uses minimal memory)

### How to Enable

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  config.enable_policy_cache = true
end
```

### Performance Impact

**Without caching:**
```ruby
# In a view with 100 posts
<% @posts.each do |post| %>
  <% if policy(post).update? %>  # Creates NEW PostPolicy instance
    <%= link_to "Edit", edit_post_path(post) %>
  <% end %>
<% end %>
# Result: 100 policy instances created
```

**With caching:**
```ruby
# Same view
<% @posts.each do |post| %>
  <% if policy(post).update? %>  # Returns CACHED PostPolicy instance
    <%= link_to "Edit", edit_post_path(post) %>
  <% end %>
<% end %>
# Result: 1 policy instance per unique (user, post, PostPolicy) combination
```

### Benchmark Example

```ruby
require 'benchmark'

user = User.find(1)
posts = Post.limit(100)

# Without caching
SimpleAuthorize.configure { |c| c.enable_policy_cache = false }
without_cache = Benchmark.measure do
  posts.each { |post| policy(post).update? }
end

# With caching
SimpleAuthorize.configure { |c| c.enable_policy_cache = true }
with_cache = Benchmark.measure do
  posts.each { |post| policy(post).update? }
end

puts "Without cache: #{without_cache.real}s"  # ~0.05s
puts "With cache: #{with_cache.real}s"        # ~0.01s (5x faster)
```

### Cache Key Structure

The cache key is built from:
```ruby
def build_policy_cache_key(record, policy_class)
  [
    authorized_user&.id,
    record&.id,
    record&.class&.name,
    policy_class.name
  ].join("-")
end
```

### Manual Cache Control

```ruby
# Clear cache mid-request if needed (rare)
clear_policy_cache

# Or in tests
def teardown
  controller.clear_policy_cache
end
```

## Instrumentation

### What is Instrumentation?

SimpleAuthorize uses `ActiveSupport::Notifications` to emit events for every authorization check. This is useful for monitoring but has a small performance cost.

### Configuration

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  # Enable in development/staging for debugging
  config.enable_instrumentation = !Rails.env.production?

  # Or enable in production with monitoring
  config.enable_instrumentation = true
end
```

### Performance Impact

- **Enabled**: ~0.01-0.02ms overhead per authorization check
- **Disabled**: No overhead

### When to Enable in Production

✅ **Enable when:**
- You need audit logging of authorization decisions
- You're tracking authorization failures for security monitoring
- You're using APM tools (New Relic, Datadog, Scout)
- You need to measure authorization performance

❌ **Disable when:**
- You need maximum performance
- You don't need authorization auditing
- You're not using the instrumentation data

### Using Instrumentation Efficiently

```ruby
# Subscribe once in an initializer, not per-request
# config/initializers/simple_authorize_monitoring.rb

if SimpleAuthorize.configuration.enable_instrumentation
  ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, id, payload|
    duration = (finish - start) * 1000  # Convert to ms

    # Only log slow authorization checks
    if duration > 10
      Rails.logger.warn(
        "Slow authorization: #{payload[:policy_class]}##{payload[:query]} took #{duration}ms"
      )
    end

    # Only log denials for security monitoring
    unless payload[:authorized]
      SecurityLogger.log_denial(payload)
    end
  end
end
```

## Database Query Optimization

### Scoping Performance

Policy scopes can impact database performance. Optimize your queries:

#### ❌ Bad: N+1 Queries
```ruby
class PostPolicy::Scope
  def resolve
    scope.select do |post|
      # This loads ALL posts into memory and filters in Ruby!
      post.user.admin? || post.published?
    end
  end
end
```

#### ✅ Good: Database Filtering
```ruby
class PostPolicy::Scope
  def resolve
    if admin?
      scope.all
    else
      # Let the database do the filtering
      scope.where(published: true)
    end
  end
end
```

#### ✅ Better: Eager Loading
```ruby
class PostPolicy::Scope
  def resolve
    base_scope = scope.includes(:user, :category)  # Prevent N+1

    if admin?
      base_scope.all
    else
      base_scope.where(published: true)
    end
  end
end
```

### Avoiding N+1 in Attribute Checks

#### ❌ Bad: Calling Associations in Policies
```ruby
class CommentPolicy
  def show?
    # This triggers a query EVERY time show? is called
    record.post.user_id == user.id
  end
end
```

#### ✅ Good: Eager Load Associations
```ruby
# In controller
def index
  @comments = policy_scope(Comment.includes(post: :user))
end

# Policy stays the same but uses cached association
class CommentPolicy
  def show?
    record.post.user_id == user.id  # No query, already loaded
  end
end
```

### Index Recommendations

Ensure your database has appropriate indexes:

```ruby
# db/migrate/xxx_add_authorization_indexes.rb
class AddAuthorizationIndexes < ActiveRecord::Migration[7.0]
  def change
    # For ownership checks
    add_index :posts, :user_id
    add_index :comments, :user_id

    # For scoping
    add_index :posts, :published
    add_index :posts, [:user_id, :published]

    # For multi-tenant apps
    add_index :projects, :tenant_id
    add_index :projects, [:tenant_id, :user_id]
  end
end
```

## View Optimization

### Policy Checks in Views

#### ❌ Bad: Multiple Checks
```erb
<% @posts.each do |post| %>
  <% if policy(post).update? %>
    <%= link_to "Edit", edit_post_path(post) %>
  <% end %>
  <% if policy(post).destroy? %>
    <%= link_to "Delete", post_path(post), method: :delete %>
  <% end %>
  <% if policy(post).publish? %>
    <%= link_to "Publish", publish_post_path(post) %>
  <% end %>
<% end %>
```

#### ✅ Good: Cache Policy Instance
```erb
<% @posts.each do |post| %>
  <% post_policy = policy(post) %>  <!-- Cache the policy -->
  <% if post_policy.update? %>
    <%= link_to "Edit", edit_post_path(post) %>
  <% end %>
  <% if post_policy.destroy? %>
    <%= link_to "Delete", post_path(post), method: :delete %>
  <% end %>
  <% if post_policy.publish? %>
    <%= link_to "Publish", publish_post_path(post) %>
  <% end %>
<% end %>
```

#### ✅ Better: Use Helper Method
```ruby
# app/helpers/authorization_helper.rb
module AuthorizationHelper
  def policy_actions(record)
    p = policy(record)
    {
      can_edit: p.update?,
      can_delete: p.destroy?,
      can_publish: p.publish?
    }
  end
end
```

```erb
<% @posts.each do |post| %>
  <% actions = policy_actions(post) %>
  <%= link_to "Edit", edit_post_path(post) if actions[:can_edit] %>
  <%= link_to "Delete", post_path(post), method: :delete if actions[:can_delete] %>
  <%= link_to "Publish", publish_post_path(post) if actions[:can_publish] %>
<% end %>
```

### Fragment Caching

Combine policy caching with fragment caching:

```erb
<% @posts.each do |post| %>
  <% cache([post, current_user]) do %>
    <div class="post">
      <%= post.title %>
      <% if policy(post).update? %>
        <%= link_to "Edit", edit_post_path(post) %>
      <% end %>
    </div>
  <% end %>
<% end %>
```

## Benchmarking

### Measuring Authorization Performance

```ruby
# lib/tasks/benchmark_authorization.rake
namespace :benchmark do
  task authorization: :environment do
    require 'benchmark'

    user = User.first
    posts = Post.limit(100).to_a

    puts "\n=== Authorization Benchmarks ==="

    Benchmark.bm(30) do |x|
      x.report("100 authorize checks:") do
        posts.each { |post| PostPolicy.new(user, post).update? }
      end

      x.report("100 policy instantiations:") do
        posts.each { |post| PostPolicy.new(user, post) }
      end

      x.report("100 scope resolutions:") do
        100.times { PostPolicy::Scope.new(user, Post.all).resolve }
      end
    end
  end
end
```

### Profiling with rack-mini-profiler

```ruby
# Gemfile
gem 'rack-mini-profiler'
gem 'memory_profiler'
gem 'stackprof'

# In a controller action you want to profile
def index
  Rack::MiniProfiler.step("Policy scoping") do
    @posts = policy_scope(Post)
  end

  Rack::MiniProfiler.step("Authorization checks") do
    @posts.each { |post| authorize post }
  end
end
```

## Production Configuration

### Recommended Production Settings

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  # Enable policy caching for performance
  config.enable_policy_cache = true

  # Disable instrumentation unless you need it
  config.enable_instrumentation = ENV['ENABLE_AUTH_MONITORING'] == 'true'

  # Keep detailed API errors off in production
  config.api_error_details = false

  # Enable I18n for user-friendly messages
  config.i18n_enabled = true

  # Custom error message
  config.default_error_message = "Access denied."
end
```

### Environment-Specific Configuration

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  if Rails.env.production?
    config.enable_policy_cache = true
    config.enable_instrumentation = false
    config.api_error_details = false
  elsif Rails.env.staging?
    config.enable_policy_cache = true
    config.enable_instrumentation = true  # Monitor in staging
    config.api_error_details = true
  else  # development, test
    config.enable_policy_cache = false  # Easier debugging
    config.enable_instrumentation = true
    config.api_error_details = true
  end
end
```

## Performance Checklist

Before deploying to production:

- [ ] Enable policy caching (`config.enable_policy_cache = true`)
- [ ] Decide on instrumentation based on monitoring needs
- [ ] Add database indexes for common authorization queries
- [ ] Eager load associations in scopes
- [ ] Use database filtering, not Ruby filtering in scopes
- [ ] Cache policy instances in views with multiple checks
- [ ] Consider fragment caching for expensive authorization views
- [ ] Profile slow pages with authorization checks
- [ ] Monitor authorization failures for security issues
- [ ] Test with production-like data volumes

## Monitoring Authorization Performance

### Custom Metrics

```ruby
# config/initializers/simple_authorize_metrics.rb
if SimpleAuthorize.configuration.enable_instrumentation
  ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, id, payload|
    duration = finish - start

    # Send to your metrics service (Datadog, StatsD, etc.)
    MetricsService.timing('authorization.check', duration, tags: [
      "policy:#{payload[:policy_class]}",
      "action:#{payload[:query]}",
      "result:#{payload[:authorized] ? 'allowed' : 'denied'}"
    ])
  end
end
```

### Slow Query Alerts

```ruby
ActiveSupport::Notifications.subscribe("policy_scope.simple_authorize") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000

  if duration > 100  # Alert on scopes taking > 100ms
    SlackNotifier.alert(
      "Slow policy scope: #{payload[:policy_scope_class]} took #{duration}ms",
      payload
    )
  end
end
```

## Conclusion

Key takeaways for optimal performance:

1. **Enable policy caching** in production for 3-5x performance improvement
2. **Optimize database queries** in scopes - use WHERE clauses, not Ruby filters
3. **Add indexes** for common authorization patterns
4. **Eager load** associations to prevent N+1 queries
5. **Cache policy instances** in views when making multiple checks
6. **Monitor** authorization performance with instrumentation
7. **Profile** your specific use cases to identify bottlenecks

SimpleAuthorize is designed to be fast out of the box, but these optimizations can provide significant performance gains in high-traffic applications.
