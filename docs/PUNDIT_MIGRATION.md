# Migrating from Pundit to SimpleAuthorize

This guide helps you migrate from Pundit to SimpleAuthorize. The two libraries have very similar APIs, making migration straightforward.

## Table of Contents

- [Why Migrate?](#why-migrate)
- [Key Differences](#key-differences)
- [Step-by-Step Migration](#step-by-step-migration)
- [Feature Comparison](#feature-comparison)
- [API Mapping](#api-mapping)
- [Edge Cases](#edge-cases)

## Why Migrate?

SimpleAuthorize offers several advantages over Pundit:

| Feature | Pundit | SimpleAuthorize |
|---------|--------|-----------------|
| **Dependencies** | Requires `activesupport` | Zero external dependencies |
| **Performance** | No caching | Built-in policy caching |
| **Monitoring** | Manual | Built-in instrumentation with ActiveSupport::Notifications |
| **API Support** | Manual | Automatic JSON/XML error handling |
| **Attribute Authorization** | Manual | Built-in visible/editable attributes |
| **Strong Parameters** | Manual | Automatic `policy_params` integration |
| **I18n** | Manual | Built-in I18n support with fallbacks |
| **Batch Operations** | Manual | Built-in `authorize_all`, `authorized_records` |
| **Test Helpers** | Basic | Comprehensive assertions for actions and attributes |

## Key Differences

### 1. Module Namespace

```ruby
# Pundit
include Pundit

# SimpleAuthorize
include SimpleAuthorize::Controller
```

### 2. Base Policy Class

```ruby
# Pundit
class ApplicationPolicy
  attr_reader :user, :record
  # ...
end

# SimpleAuthorize
class ApplicationPolicy < SimpleAuthorize::Policy
  # user and record are already defined
  # helper methods (admin?, owner?, etc.) already available
end
```

### 3. Error Classes

```ruby
# Pundit
Pundit::NotAuthorizedError
Pundit::NotDefinedError

# SimpleAuthorize
SimpleAuthorize::Controller::NotAuthorizedError
SimpleAuthorize::Controller::PolicyNotDefinedError
```

### 4. Verification Methods

```ruby
# Pundit
after_action :verify_authorized
after_action :verify_policy_scoped

# SimpleAuthorize (same, but also has AutoVerify module)
after_action :verify_authorized
after_action :verify_policy_scoped

# Or use AutoVerify module
include SimpleAuthorize::Controller::AutoVerify
```

## Step-by-Step Migration

### Step 1: Update Gemfile

```ruby
# Remove
gem 'pundit'

# Add
gem 'simple_authorize'
```

```bash
bundle install
```

### Step 2: Update ApplicationController

```ruby
# Before (Pundit)
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
end

# After (SimpleAuthorize)
class ApplicationController < ActionController::Base
  include SimpleAuthorize::Controller
  rescue_from_authorization_errors  # Built-in helper method

  # That's it! The rest is handled automatically
  # Or customize:
  # rescue_from SimpleAuthorize::Controller::NotAuthorizedError, with: :user_not_authorized
end
```

### Step 3: Update ApplicationPolicy

```ruby
# Before (Pundit)
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  # ... other methods ...

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end
end

# After (SimpleAuthorize)
class ApplicationPolicy < SimpleAuthorize::Policy
  # user, record, initialize already defined!
  # Default deny-all methods already defined!
  # Helper methods (admin?, owner?, logged_in?) already available!

  class Scope < SimpleAuthorize::Policy::Scope
    # user, scope, initialize already defined!

    def resolve
      scope.all
    end
  end
end
```

### Step 4: Update Policies (Minimal Changes)

Your existing policy methods work as-is! Just update the base class:

```ruby
# Before (Pundit)
class PostPolicy < ApplicationPolicy
  def update?
    user.admin? || record.user_id == user.id
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

# After (SimpleAuthorize) - identical logic!
class PostPolicy < ApplicationPolicy
  def update?
    admin? || owner?  # Can use built-in helpers!
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      else
        scope.where(published: true)
      end
    end
  end
end
```

### Step 5: Update Error Handling

```ruby
# Before (Pundit)
rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

# After (SimpleAuthorize)
rescue_from SimpleAuthorize::Controller::NotAuthorizedError, with: :user_not_authorized

# Or use the built-in helper:
rescue_from_authorization_errors
```

### Step 6: Update Tests

```ruby
# Before (Pundit) - manual assertions
test "admin can destroy post" do
  policy = PostPolicy.new(admin_user, post)
  assert policy.destroy?
end

# After (SimpleAuthorize) - use test helpers
include SimpleAuthorize::TestHelpers

test "admin can destroy post" do
  policy = PostPolicy.new(admin_user, post)
  assert_permit_action policy, :destroy
end
```

## Feature Comparison

### Basic Authorization

Both libraries work identically:

```ruby
# Both Pundit and SimpleAuthorize
def update
  @post = Post.find(params[:id])
  authorize @post
  # ...
end
```

### Scoping

Both libraries work identically:

```ruby
# Both Pundit and SimpleAuthorize
def index
  @posts = policy_scope(Post)
end
```

### Policy Lookups

Both libraries work identically:

```ruby
# Both Pundit and SimpleAuthorize
policy = policy(@post)
policy.update?  # => true/false
```

### New Features in SimpleAuthorize

#### 1. Attribute-Level Authorization

```ruby
# Not in Pundit - manual implementation needed
# SimpleAuthorize - built-in!

class PostPolicy < ApplicationPolicy
  def visible_attributes
    if admin?
      [:id, :title, :body, :user_id]
    else
      [:id, :title]
    end
  end
end

# In controller:
@visible_attrs = visible_attributes(@post)
```

#### 2. Strong Parameters Integration

```ruby
# Pundit - manual
params.require(:post).permit(:title, :body)

# SimpleAuthorize - automatic!
policy_params(@post)  # Automatically permits based on policy
```

#### 3. Policy Caching

```ruby
# SimpleAuthorize only
SimpleAuthorize.configure do |config|
  config.enable_policy_cache = true
end

# Policies are now cached per-request
policy(@post)  # Creates policy
policy(@post)  # Returns cached policy (same object)
```

#### 4. Instrumentation

```ruby
# SimpleAuthorize only
ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, id, payload|
  Rails.logger.info "Auth check: #{payload[:authorized]}"
end
```

#### 5. Batch Operations

```ruby
# SimpleAuthorize only
authorize_all(@posts, :update?)  # Raises if any fail
authorized = authorized_records(@posts, :update?)  # Returns only authorized
allowed, denied = partition_records(@posts, :update?)  # Splits into two arrays
```

## API Mapping

### Controller Methods

| Pundit | SimpleAuthorize | Notes |
|--------|-----------------|-------|
| `authorize(record)` | `authorize(record)` | Identical |
| `authorize(record, :action?)` | `authorize(record, :action?)` | Identical |
| `policy(record)` | `policy(record)` | Identical |
| `policy_scope(scope)` | `policy_scope(scope)` | Identical |
| `verify_authorized` | `verify_authorized` | Identical |
| `verify_policy_scoped` | `verify_policy_scoped` | Identical |
| `skip_authorization` | `skip_authorization_check` | Different name |
| `skip_policy_scope` | `skip_policy_scope_check` | Different name |
| `pundit_user` | `authorized_user` | Different name |
| N/A | `policy_params(record)` | New in SimpleAuthorize |
| N/A | `visible_attributes(record)` | New in SimpleAuthorize |
| N/A | `editable_attributes(record)` | New in SimpleAuthorize |
| N/A | `authorize_all(records, :action?)` | New in SimpleAuthorize |
| N/A | `authorized_records(records, :action?)` | New in SimpleAuthorize |

### Configuration

| Pundit | SimpleAuthorize | Notes |
|--------|-----------------|-------|
| `Pundit.policy_scope!` | `policy_scope!` | Same behavior |
| `Pundit.authorize` | `authorize` | Same behavior |
| `pundit_user` method | `authorized_user` method | Override in controller |
| N/A | `SimpleAuthorize.configure` | New configuration block |

## Edge Cases

### 1. Headless Policies (no record)

```ruby
# Pundit
authorize :dashboard, :show?

# SimpleAuthorize - same, but also supports:
authorize_headless(DashboardPolicy, :show?)
```

### 2. Custom Policy Classes

```ruby
# Both work the same
authorize @post, policy_class: AdminPostPolicy
```

### 3. Namespace Policies

```ruby
# Both work the same
authorize @post, policy_class: Admin::PostPolicy
```

### 4. Policy Inheritance

```ruby
# Both work the same - standard Ruby inheritance
class PostPolicy < ApplicationPolicy
  # ...
end
```

### 5. Testing Policies in Isolation

```ruby
# Pundit
policy = PostPolicy.new(user, post)
assert policy.update?

# SimpleAuthorize - same, plus helpers:
include SimpleAuthorize::TestHelpers
policy = PostPolicy.new(user, post)
assert_permit_action policy, :update
```

## Common Pitfalls

### 1. Module Name

**Problem:** Forgetting to update module name

```ruby
# ✗ Wrong
include Pundit

# ✓ Correct
include SimpleAuthorize::Controller
```

### 2. Error Class Names

**Problem:** Rescue handler still using Pundit error class

```ruby
# ✗ Wrong
rescue_from Pundit::NotAuthorizedError

# ✓ Correct
rescue_from SimpleAuthorize::Controller::NotAuthorizedError

# ✓ Or just use:
rescue_from_authorization_errors
```

### 3. Helper Method Names

**Problem:** Using Pundit's `pundit_user`

```ruby
# ✗ Wrong (Pundit)
def pundit_user
  current_admin
end

# ✓ Correct (SimpleAuthorize)
def authorized_user
  current_admin
end
```

### 4. Base Class

**Problem:** Not inheriting from SimpleAuthorize::Policy

```ruby
# ✗ Wrong
class ApplicationPolicy
  attr_reader :user, :record
  # ...
end

# ✓ Correct
class ApplicationPolicy < SimpleAuthorize::Policy
  # user and record already defined!
end
```

## Performance Considerations

SimpleAuthorize includes performance optimizations:

1. **Policy Caching**: Enable for better performance in views
2. **Instrumentation**: Disabled by default in production for performance
3. **Zero Dependencies**: Faster load times

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  config.enable_policy_cache = Rails.env.production?
  config.enable_instrumentation = !Rails.env.production?
end
```

## Rollback Plan

If you need to rollback:

1. Keep SimpleAuthorize gem installed alongside Pundit temporarily
2. Change controller inclusion back to Pundit
3. Revert error handling changes
4. Update Gemfile to remove simple_authorize

The policies themselves don't need to change - they work with both!

## Getting Help

- GitHub Issues: https://github.com/scottlaplant/simple_authorize/issues
- Documentation: https://github.com/scottlaplant/simple_authorize/wiki
- Examples: See `examples/` directory in the gem

## Conclusion

Migration from Pundit to SimpleAuthorize is straightforward:

1. ✅ Similar API - most code works as-is
2. ✅ Better features - attribute auth, caching, instrumentation
3. ✅ Zero dependencies - simpler stack
4. ✅ Better performance - built-in optimizations
5. ✅ Easy rollback - policies work with both

The migration typically takes 15-30 minutes for a small app, and 1-2 hours for larger applications.
