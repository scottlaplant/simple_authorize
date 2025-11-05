# Policy Composition

Policy Composition allows you to build complex authorization policies by combining reusable modules. This feature promotes DRY (Don't Repeat Yourself) principles and ensures consistent authorization patterns across your application.

## Table of Contents
- [Overview](#overview)
- [Built-in Modules](#built-in-modules)
- [Usage Examples](#usage-examples)
- [Creating Custom Modules](#creating-custom-modules)
- [Best Practices](#best-practices)

## Overview

Instead of duplicating authorization logic across multiple policies, you can extract common patterns into modules and include them where needed.

```ruby
class ArticlePolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Ownable
  include SimpleAuthorize::PolicyModules::Publishable

  def show?
    published? || owner_or_admin?
  end
end
```

## Built-in Modules

SimpleAuthorize provides five ready-to-use policy modules:

### Ownable

Provides ownership-based authorization helpers.

**Methods:**
- `owner?` - Checks if the current user owns the record
- `owner_or_admin?` - Checks if user is owner or admin
- `owner_or_contributor?` - Checks if user is owner or contributor
- `can_modify?` - Common pattern for modification rights
- `standard_permissions` - Returns hash of standard CRUD permissions

**Example:**
```ruby
class PostPolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Ownable

  def update?
    owner_or_admin?
  end

  def destroy?
    owner_or_admin?
  end
end
```

### Publishable

For content with draft/published states.

**Methods:**
- `published?` - Checks if record is published
- `draft?` - Checks if record is a draft
- `can_publish?` - Checks if user can publish
- `can_unpublish?` - Checks if user can unpublish
- `can_preview?` - Checks if user can preview drafts
- `can_schedule?` - Checks if user can schedule publication
- `publishable_visible_attributes` - Filters attributes based on published state

**Example:**
```ruby
class ArticlePolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Publishable

  def show?
    published? || can_preview?
  end

  def visible_attributes
    publishable_visible_attributes([:title, :body, :author, :internal_notes])
  end
end
```

### Timestamped

Time-based authorization controls.

**Methods:**
- `expired?` / `not_expired?` - Checks expiration status
- `active?` - Checks if record is within active time range
- `started?` / `ended?` - Checks time boundaries
- `within_time_window?` - Checks if in valid time range
- `locked?` - Checks if record is time-locked
- `can_modify_time_based?` - Checks if modifications are allowed based on time
- `within_business_hours?` - Checks if within business hours

**Example:**
```ruby
class EventPolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Timestamped

  def update?
    not_expired? && can_modify_time_based? && owner_or_admin?
  end

  def register?
    active? && !expired?
  end
end
```

### Approvable

For approval workflow management.

**Methods:**
- `approved?` / `not_approved?` - Checks approval status
- `pending_approval?` - Checks if pending
- `rejected?` - Checks if rejected
- `can_approve?` - Checks if user can approve (not their own content)
- `can_reject?` - Checks if user can reject
- `can_submit_for_approval?` - Checks if can submit
- `can_withdraw_approval?` - Checks if can withdraw
- `can_edit_with_approval?` - Checks edit permissions based on approval status

**Example:**
```ruby
class DocumentPolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Approvable
  include SimpleAuthorize::PolicyModules::Ownable

  def update?
    can_edit_with_approval?
  end

  def approve?
    can_approve? # Ensures users can't approve their own content
  end
end
```

### SoftDeletable

For soft deletion support.

**Methods:**
- `soft_deleted?` / `not_deleted?` - Checks deletion status
- `soft_deletable?` - Checks if record supports soft deletion
- `can_restore?` - Checks if user can restore
- `can_permanently_destroy?` - Checks if can hard delete
- `within_restore_window?` - Checks if within restoration period
- `can_view_deleted?` - Checks if can view deleted records
- `safe_destroy?` - Returns appropriate destroy permission

**Example:**
```ruby
class CommentPolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::SoftDeletable

  def destroy?
    safe_destroy?
  end

  def restore?
    can_restore?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all # Includes soft-deleted
      else
        scope.where(deleted_at: nil)
      end
    end
  end
end
```

## Usage Examples

### Combining Multiple Modules

```ruby
class ArticlePolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Ownable
  include SimpleAuthorize::PolicyModules::Publishable
  include SimpleAuthorize::PolicyModules::Timestamped

  def show?
    return true if published? && not_expired?
    owner_or_admin?
  end

  def update?
    return false if expired? || locked?

    if published?
      admin?
    else
      owner_or_admin?
    end
  end

  def destroy?
    owner_or_admin? && draft?
  end
end
```

### Module Inclusion Order

The order of module inclusion matters. Later modules override earlier ones:

```ruby
class PolicyWithOrderedModules < ApplicationPolicy
  include ModuleA  # Defines update?
  include ModuleB  # Overrides update? from ModuleA
end
```

To ensure a module's methods take precedence, use `prepend`:

```ruby
class PolicyWithPrepend < ApplicationPolicy
  include BaseModule
  prepend OverrideModule  # OverrideModule methods always win
end
```

## Creating Custom Modules

Create your own policy modules for application-specific patterns:

```ruby
module PolicyModules
  module Subscribable
    protected

    def subscriber?
      user&.subscription&.active?
    end

    def premium_subscriber?
      user&.subscription&.plan == 'premium'
    end

    def trial_expired?
      user&.subscription&.trial_ended_at&.past?
    end

    def can_access_premium_content?
      premium_subscriber? || admin?
    end
  end
end

class PremiumContentPolicy < ApplicationPolicy
  include PolicyModules::Subscribable

  def show?
    can_access_premium_content?
  end
end
```

## Best Practices

### 1. Keep Modules Focused
Each module should handle one concern (ownership, publishing, etc.).

### 2. Use Descriptive Names
Module names should clearly indicate their purpose.

### 3. Document Dependencies
If a module depends on another module's methods, document it:

```ruby
module RequiresOwnable
  # This module requires SimpleAuthorize::PolicyModules::Ownable
  def special_permission?
    owner? && some_other_condition?
  end
end
```

### 4. Test Module Combinations
Test policies that use multiple modules to ensure they interact correctly:

```ruby
class ArticlePolicyTest < ActiveSupport::TestCase
  def setup
    @policy = ArticlePolicy.new(user, article)
  end

  test "combines ownership and publishing rules correctly" do
    # Test the interaction between modules
  end
end
```

### 5. Avoid Method Name Conflicts
Be aware of methods defined in multiple modules:

```ruby
# If both modules define `can_edit?`, the last included wins
include ModuleA  # defines can_edit?
include ModuleB  # also defines can_edit? - this one wins
```

### 6. Extract Common Patterns
If you find yourself writing similar authorization logic in multiple policies, extract it into a module:

```ruby
# Before: Duplicated in multiple policies
class PostPolicy < ApplicationPolicy
  def publish?
    admin? || (owner? && user.verified?)
  end
end

class ArticlePolicy < ApplicationPolicy
  def publish?
    admin? || (owner? && user.verified?)
  end
end

# After: Extracted to module
module VerifiedPublishable
  def publish?
    admin? || (owner? && user.verified?)
  end
end

class PostPolicy < ApplicationPolicy
  include VerifiedPublishable
end

class ArticlePolicy < ApplicationPolicy
  include VerifiedPublishable
end
```

## Migration from Duplicated Code

If you have existing policies with duplicated logic, here's how to migrate:

1. Identify common patterns across policies
2. Extract them into modules
3. Include modules in policies
4. Remove duplicated methods
5. Test thoroughly

Before:
```ruby
class PostPolicy < ApplicationPolicy
  def update?
    user&.id == record.user_id || user&.admin?
  end
end

class CommentPolicy < ApplicationPolicy
  def update?
    user&.id == record.user_id || user&.admin?
  end
end
```

After:
```ruby
class PostPolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Ownable

  def update?
    owner_or_admin?
  end
end

class CommentPolicy < ApplicationPolicy
  include SimpleAuthorize::PolicyModules::Ownable

  def update?
    owner_or_admin?
  end
end
```

## Related Topics

- [Context-Aware Policies](Context-Aware-Policies) - Pass request context to policies
- [Testing Policies](Testing-Policies) - Test policies with modules
- [Best Practices](Best-Practices) - General authorization best practices