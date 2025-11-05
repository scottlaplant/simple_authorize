# SimpleAuthorize

[![Gem Version](https://img.shields.io/gem/v/simple_authorize.svg)](https://rubygems.org/gems/simple_authorize)
[![Ruby](https://github.com/scottlaplant/simple_authorize/workflows/Ruby/badge.svg)](https://github.com/scottlaplant/simple_authorize/actions)
[![Downloads](https://img.shields.io/gem/dt/simple_authorize.svg)](https://rubygems.org/gems/simple_authorize)

SimpleAuthorize is a lightweight, powerful authorization framework for Rails that provides policy-based access control without external dependencies. Inspired by Pundit, it offers a clean API for managing permissions in your Rails applications.

## Features

- **Policy-Based Authorization** - Define authorization rules in dedicated policy classes
- **Scope Filtering** - Automatically filter collections based on user permissions
- **Role-Based Access** - Built-in support for role-based authorization
- **Policy Composition** - Mix and match reusable authorization modules
- **Context-Aware Policies** - Make authorization decisions based on request context (IP, time, location, etc.)
- **Zero Dependencies** - No external gems required (only Rails)
- **Strong Parameters Integration** - Automatically build permitted params from policies
- **Test Friendly** - Easy to test policies in isolation
- **Rails Generators** - Quickly scaffold policies for your models

## Installation

Install the gem directly:

```bash
gem install simple_authorize
```

Or add this line to your application's Gemfile:

```ruby
gem 'simple_authorize'
```

Then execute:

```bash
bundle install
```

After installation, run the generator to set up your application:

```bash
rails generate simple_authorize:install
```

This will create:
- `config/initializers/simple_authorize.rb` - Configuration file
- `app/policies/application_policy.rb` - Base policy class

## Quick Start

### 1. Include SimpleAuthorize in your ApplicationController

```ruby
class ApplicationController < ActionController::Base
  include SimpleAuthorize::Controller
  rescue_from_authorization_errors
end
```

### 2. Create a Policy

Generate a policy for your model using the generator:

```bash
rails generate simple_authorize:policy Post
```

This creates:
- `app/policies/post_policy.rb` - Policy class with CRUD methods
- `test/policies/post_policy_test.rb` - Test file (or spec file with `--spec`)

Or create a policy class manually in `app/policies/`:

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (record.user_id == user.id || user.admin?)
  end

  def destroy?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(published: true)
      end
    end
  end
end
```

### 3. Use Authorization in Your Controllers

```ruby
class PostsController < ApplicationController
  def index
    @posts = policy_scope(Post)
  end

  def show
    @post = Post.find(params[:id])
    authorize @post
  end

  def create
    @post = Post.new(post_params)
    authorize @post

    if @post.save
      redirect_to @post
    else
      render :new
    end
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :published)
  end
end
```

### 4. Use in Views

Check permissions in your views:

```erb
<% if policy(@post).update? %>
  <%= link_to "Edit", edit_post_path(@post) %>
<% end %>

<% if policy(@post).destroy? %>
  <%= link_to "Delete", post_path(@post), method: :delete %>
<% end %>
```

## Core Concepts

### Policies

Policies are plain Ruby objects that encapsulate authorization logic. Each policy corresponds to a model and defines what actions users can perform.

```ruby
class PostPolicy < ApplicationPolicy
  def update?
    # Only the owner or an admin can update
    user.present? && (record.user_id == user.id || user.admin?)
  end
end
```

### Scopes

Scopes filter collections based on user permissions:

```ruby
class PostPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(published: true)
      end
    end
  end
end
```

Use in controllers:

```ruby
def index
  @posts = policy_scope(Post)
end
```

### Strong Parameters

SimpleAuthorize can automatically build permitted parameters from policies:

```ruby
class PostPolicy < ApplicationPolicy
  def permitted_attributes
    if user&.admin?
      [:title, :body, :published, :featured]
    else
      [:title, :body]
    end
  end
end
```

Use in controllers:

```ruby
def post_params
  policy_params(Post, :post)
  # Or manually:
  # params.require(:post).permit(*permitted_attributes(Post.new))
end
```

## Generators

SimpleAuthorize provides Rails generators to quickly scaffold policies:

### Install Generator

```bash
rails generate simple_authorize:install
```

Creates:
- `config/initializers/simple_authorize.rb` - Configuration file
- `app/policies/application_policy.rb` - Base policy class

### Policy Generator

```bash
rails generate simple_authorize:policy Post
```

Creates:
- `app/policies/post_policy.rb` - Policy with CRUD methods and scope
- `test/policies/post_policy_test.rb` - Minitest tests

**Options:**
- `--spec` - Generate RSpec tests instead of Minitest
- `--skip-test` - Skip test file generation

**Examples:**

```bash
# Generate policy with RSpec tests
rails generate simple_authorize:policy Post --spec

# Generate policy without tests
rails generate simple_authorize:policy Post --skip-test

# Generate namespaced policy
rails generate simple_authorize:policy Admin::Post
```

## Configuration

SimpleAuthorize can be configured in `config/initializers/simple_authorize.rb`:

### Policy Caching

Enable policy caching to improve performance by caching policy instances per request:

```ruby
SimpleAuthorize.configure do |config|
  config.enable_policy_cache = true
end
```

**How it works:**
- Policy instances are cached for the duration of a single request
- Cache is automatically scoped by user, record, and policy class
- Each unique combination gets its own cached instance
- Cache is automatically cleared between requests
- Particularly useful in views where the same policy may be checked multiple times

**Example performance impact:**

```erb
<!-- Without caching: Creates 3 separate PostPolicy instances -->
<% if policy(@post).update? %>
  <%= link_to "Edit", edit_post_path(@post) %>
<% end %>
<% if policy(@post).destroy? %>
  <%= link_to "Delete", post_path(@post) %>
<% end %>
<% if policy(@post).publish? %>
  <%= link_to "Publish", publish_post_path(@post) %>
<% end %>

<!-- With caching: Reuses the same PostPolicy instance -->
```

**Testing:**
Use `clear_policy_cache` or `reset_authorization` to clear the cache in tests:

```ruby
test "multiple checks use cached policy" do
  SimpleAuthorize.configure { |config| config.enable_policy_cache = true }

  policy1 = policy(@post)
  policy2 = policy(@post)
  assert_same policy1, policy2  # Same instance

  clear_policy_cache
  policy3 = policy(@post)
  refute_same policy1, policy3  # New instance after clearing
end
```

### Instrumentation & Audit Logging

SimpleAuthorize emits `ActiveSupport::Notifications` events for all authorization checks, perfect for security auditing, debugging, and monitoring:

```ruby
# Subscribe to authorization events
ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, id, payload|
  duration = finish - start

  Rails.logger.info({
    event: "authorization",
    user_id: payload[:user_id],
    action: payload[:query],
    resource: "#{payload[:record_class]}##{payload[:record_id]}",
    authorized: payload[:authorized],
    duration_ms: (duration * 1000).round(2)
  }.to_json)
end

# Subscribe to policy scope events
ActiveSupport::Notifications.subscribe("policy_scope.simple_authorize") do |name, start, finish, id, payload|
  Rails.logger.info("Policy scope applied for #{payload[:scope]} by user #{payload[:user_id]}")
end
```

**Event Payloads:**

Authorization events (`authorize.simple_authorize`):
- `user`: Current user object
- `user_id`: User ID
- `record`: The record being authorized
- `record_id`: Record ID
- `record_class`: Record class name
- `query`: Authorization method called (e.g., "update?")
- `policy_class`: Policy class used
- `authorized`: Boolean result
- `error`: Exception if authorization failed
- `controller`: Controller name (if available)
- `action`: Action name (if available)

Policy scope events (`policy_scope.simple_authorize`):
- `user`: Current user object
- `user_id`: User ID
- `scope`: The scope being filtered
- `policy_scope_class`: Scope class used
- `error`: Exception if scope failed
- `controller`: Controller name (if available)
- `action`: Action name (if available)

**Use Cases:**
- Security auditing and compliance
- Debugging authorization issues
- Monitoring authorization performance
- Sending failed authorization attempts to security services
- Tracking which users access sensitive resources

**Disable instrumentation** (if needed for performance in specific scenarios):

```ruby
SimpleAuthorize.configure do |config|
  config.enable_instrumentation = false
end
```

### Other Configuration Options

```ruby
SimpleAuthorize.configure do |config|
  # Custom error message for unauthorized access
  config.default_error_message = "Access denied!"

  # Custom redirect path for unauthorized users
  config.unauthorized_redirect_path = "/access-denied"

  # Custom method to get current user (default: current_user)
  config.current_user_method = :authenticated_user
end
```

## Policy Composition

Policy Composition allows you to build complex authorization policies by combining reusable modules. This promotes DRY code and consistent authorization patterns across your application.

### Using Built-in Policy Modules

SimpleAuthorize provides several ready-to-use policy modules:

```ruby
class ArticlePolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Ownable
  include SimpleAuthorize::PolicyModules::Publishable

  def show?
    published? || owner_or_admin?
  end

  def update?
    owner_or_admin? && not_published?
  end
end
```

### Available Policy Modules

#### Ownable
Provides ownership-based authorization:
- `owner?` - Check if user owns the record
- `owner_or_admin?` - Check if user is owner or admin
- `can_modify?` - Common pattern for modification rights

#### Publishable
For content with draft/published states:
- `published?` - Check if record is published
- `can_publish?` - Check if user can publish
- `can_preview?` - Check if user can preview drafts

#### Timestamped
Time-based authorization:
- `expired?` - Check if record has expired
- `within_time_window?` - Check if record is in valid time range
- `locked?` - Check if record is time-locked

#### Approvable
For approval workflows:
- `approved?` - Check if record is approved
- `can_approve?` - Check if user can approve (not their own content)
- `can_submit_for_approval?` - Check if user can submit for approval

#### SoftDeletable
For soft deletion support:
- `soft_deleted?` - Check if record is soft deleted
- `can_restore?` - Check if user can restore
- `can_permanently_destroy?` - Check if user can hard delete

### Creating Custom Policy Modules

```ruby
module MyApp::PolicyModules::Subscribable
  protected

  def subscriber?
    user&.subscriptions&.active&.any?
  end

  def premium_subscriber?
    user&.subscription&.premium?
  end

  def can_access_premium_content?
    premium_subscriber? || admin?
  end
end

class PremiumContentPolicy < ApplicationPolicy
  include MyApp::PolicyModules::Subscribable

  def show?
    can_access_premium_content?
  end
end
```

## Context-Aware Policies

Context-Aware Policies allow you to make authorization decisions based on additional context beyond just the user and record. This is useful for IP-based restrictions, time-based access, rate limiting, and more.

### Basic Usage

Override the `authorization_context` method in your controller:

```ruby
class ApplicationController < ActionController::Base
  include SimpleAuthorize::Controller

  private

  def authorization_context
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      current_time: Time.current,
      country: request.location&.country,
      two_factor_verified: session[:two_factor_verified],
      user_plan: current_user&.subscription&.plan
    }
  end
end
```

### Using Context in Policies

Access context in your policies through the `context` method:

```ruby
class SecureDocumentPolicy < ApplicationPolicy
  def show?
    # Require 2FA for sensitive documents
    return false unless context[:two_factor_verified]

    # Check IP restrictions
    return false unless trusted_ip?

    owner_or_admin?
  end

  private

  def trusted_ip?
    return true if context[:ip_address].nil?

    trusted_ips = ["192.168.1.0/24", "10.0.0.0/8"]
    trusted_ips.any? { |range| IPAddr.new(range).include?(context[:ip_address]) }
  end
end
```

### Common Context Patterns

#### Geographic Restrictions
```ruby
class RegionalContentPolicy < ApplicationPolicy
  def show?
    allowed_countries = ["US", "CA", "UK"]
    allowed_countries.include?(context[:country]) || admin?
  end
end
```

#### Time-Based Access
```ruby
class BusinessHoursPolicy < ApplicationPolicy
  def create?
    return true if admin?

    hour = context[:current_time].hour
    hour >= 9 && hour < 17  # 9 AM to 5 PM only
  end
end
```

#### Rate Limiting
```ruby
class ApiPolicy < ApplicationPolicy
  def create?
    return true if admin?

    request_count = context[:request_count] || 0
    request_count < 100  # Limit to 100 requests
  end
end
```

#### Plan-Based Features
```ruby
class ExportPolicy < ApplicationPolicy
  def export?
    case context[:user_plan]
    when "enterprise"
      true
    when "pro"
      owner_or_admin?
    when "basic"
      admin?
    else
      false
    end
  end
end
```

### Context with Policy Scopes

Context is also available in policy scopes:

```ruby
class DocumentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if context[:department]
        scope.where(department: context[:department])
      elsif user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end
```

## Advanced Features

### Headless Policies

For policies that don't correspond to a model:

```ruby
class DashboardPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end
end

# In controller:
def show
  authorize_headless(DashboardPolicy)
end
```

### Custom Query Methods

Define custom authorization queries:

```ruby
class PostPolicy < ApplicationPolicy
  def publish?
    user&.admin? || (user&.contributor? && owner?)
  end
end

# In controller:
authorize @post, :publish?
```

### Automatic Verification

Ensure every action is authorized:

```ruby
class ApplicationController < ActionController::Base
  include SimpleAuthorize::Controller
  include SimpleAuthorize::Controller::AutoVerify  # Enable auto-verification
  rescue_from_authorization_errors
end
```

This will require `authorize` or `policy_scope` in all actions.

Skip verification when needed:

```ruby
class PublicController < ApplicationController
  skip_authorization_check :index, :show
end
```

## Testing

Test policies in isolation:

```ruby
require 'test_helper'

class PostPolicyTest < ActiveSupport::TestCase
  test "admin can update any post" do
    admin = users(:admin)
    post = posts(:one)
    policy = PostPolicy.new(admin, post)

    assert policy.update?
  end

  test "user can only update their own posts" do
    user = users(:regular)
    own_post = posts(:user_post)
    other_post = posts(:other_post)

    assert PostPolicy.new(user, own_post).update?
    refute PostPolicy.new(user, other_post).update?
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Comparison with Pundit

SimpleAuthorize is heavily inspired by Pundit and offers a similar API. Key differences:

| Feature | SimpleAuthorize | Pundit |
|---------|----------------|--------|
| Dependencies | None (Rails only) | Standalone gem |
| Base class | `SimpleAuthorize::Policy` | `ApplicationPolicy` (user-defined) |
| Installation | Generator creates base policy | Manual setup required |
| Module name | `SimpleAuthorize::Controller` | `Pundit` |
| Compatibility | Rails 6.0+ | Rails 4.0+ |

Migration from Pundit is straightforward - most code will work with minimal changes.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scottlaplant/simple_authorize.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

SimpleAuthorize is heavily inspired by [Pundit](https://github.com/varvet/pundit) by Elabs. We're grateful to the Pundit team for pioneering this authorization pattern.
