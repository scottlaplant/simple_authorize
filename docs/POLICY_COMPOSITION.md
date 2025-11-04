# Policy Composition Guide

This guide covers using Ruby modules to compose reusable authorization logic across policies.

## Table of Contents

- [Overview](#overview)
- [Why Use Policy Composition?](#why-use-policy-composition)
- [Basic Module Inclusion](#basic-module-inclusion)
- [Common Shared Modules](#common-shared-modules)
- [Advanced Patterns](#advanced-patterns)
- [Module Organization](#module-organization)
- [Testing Composed Policies](#testing-composed-policies)
- [Best Practices](#best-practices)

## Overview

Policy composition allows you to extract common authorization patterns into reusable modules that can be included in multiple policy classes. This promotes DRY (Don't Repeat Yourself) principles and makes your authorization logic more maintainable.

### Inheritance vs Composition

**Inheritance** (what you already have):
```ruby
class PostPolicy < ApplicationPolicy
  # Inherits from ApplicationPolicy
end
```

**Composition** (what this guide covers):
```ruby
class PostPolicy < ApplicationPolicy
  include Ownable      # Include reusable modules
  include Publishable
  include Timestamped
end
```

## Why Use Policy Composition?

### 1. Reduce Code Duplication

❌ **Without Composition:**
```ruby
class PostPolicy < ApplicationPolicy
  def publish?
    admin? || (contributor? && record.user_id == user&.id)
  end
end

class ArticlePolicy < ApplicationPolicy
  def publish?
    admin? || (contributor? && record.user_id == user&.id)  # Duplicated!
  end
end

class PagePolicy < ApplicationPolicy
  def publish?
    admin? || (contributor? && record.user_id == user&.id)  # Duplicated!
  end
end
```

✅ **With Composition:**
```ruby
module Publishable
  def publish?
    admin? || (contributor? && owner?)
  end

  def unpublish?
    publish?
  end
end

class PostPolicy < ApplicationPolicy
  include Publishable  # Reuse!
end

class ArticlePolicy < ApplicationPolicy
  include Publishable  # Reuse!
end

class PagePolicy < ApplicationPolicy
  include Publishable  # Reuse!
end
```

### 2. Organize Related Logic

Group related authorization concerns together:

```ruby
module Commentable
  def create_comment?
    logged_in?
  end

  def moderate_comments?
    owner? || admin?
  end

  def delete_comment?
    admin?
  end
end

class PostPolicy < ApplicationPolicy
  include Commentable
end

class ArticlePolicy < ApplicationPolicy
  include Commentable
end
```

### 3. Share Attribute Logic

```ruby
module ContentAttributes
  def visible_attributes
    if admin?
      base_attributes + admin_attributes
    elsif owner?
      base_attributes + owner_attributes
    else
      base_attributes
    end
  end

  private

  def base_attributes
    [:id, :title, :body, :created_at]
  end

  def owner_attributes
    [:published, :updated_at]
  end

  def admin_attributes
    [:user_id, :internal_notes]
  end
end
```

## Basic Module Inclusion

### Creating a Shared Module

```ruby
# app/policies/concerns/ownable.rb
module Ownable
  def owner?
    record.respond_to?(:user_id) && record.user_id == user&.id
  end

  def owner_or_admin?
    owner? || admin?
  end
end
```

### Including in Policies

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  include Ownable

  def update?
    owner_or_admin?  # Method from Ownable module
  end

  def destroy?
    owner_or_admin?
  end
end
```

### Method Precedence

Policy methods override module methods:

```ruby
module Publishable
  def publish?
    contributor? && owner?
  end
end

class PostPolicy < ApplicationPolicy
  include Publishable

  # This overrides Publishable#publish?
  def publish?
    super || admin?  # Call module's method with super
  end
end
```

## Common Shared Modules

### 1. Ownable - Ownership Checks

```ruby
# app/policies/concerns/ownable.rb
module Ownable
  # Check if current user owns the record
  def owner?
    record.respond_to?(:user_id) && record.user_id == user&.id
  end

  # Check if user owns OR is admin
  def owner_or_admin?
    owner? || admin?
  end

  # Common pattern: update/destroy own resources
  def update?
    owner_or_admin?
  end

  def destroy?
    owner_or_admin?
  end
end

# Usage
class CommentPolicy < ApplicationPolicy
  include Ownable
  # Gets update? and destroy? for free
end
```

### 2. Publishable - Publishing Workflow

```ruby
# app/policies/concerns/publishable.rb
module Publishable
  def publish?
    return true if admin?
    contributor? && owner?
  end

  def unpublish?
    publish?  # Same rules
  end

  def schedule?
    publish?  # Can schedule if can publish
  end

  # Visibility based on published status
  def show?
    return true if admin? || owner?
    record.respond_to?(:published?) && record.published?
  end
end

# Usage
class PostPolicy < ApplicationPolicy
  include Publishable
end

class ArticlePolicy < ApplicationPolicy
  include Publishable
end
```

### 3. Timestamped - Time-Based Rules

```ruby
# app/policies/concerns/timestamped.rb
module Timestamped
  def recent?
    record.created_at > 7.days.ago
  end

  def stale?
    !recent?
  end

  def editable_period?
    record.created_at > 1.hour.ago
  end

  # Can edit if recent AND owner
  def update?
    owner? && editable_period?
  end
end

# Usage
class CommentPolicy < ApplicationPolicy
  include Timestamped
  # Comments can only be edited within 1 hour of creation
end
```

### 4. Approvable - Approval Workflow

```ruby
# app/policies/concerns/approvable.rb
module Approvable
  def approve?
    admin? || moderator?
  end

  def reject?
    approve?
  end

  def pending?
    record.respond_to?(:status) && record.status == 'pending'
  end

  def approved?
    record.respond_to?(:status) && record.status == 'approved'
  end

  # Only show approved items to non-moderators
  def show?
    return true if admin? || moderator?
    approved?
  end
end

# Usage
class CommentPolicy < ApplicationPolicy
  include Approvable
end
```

### 5. Archivable - Archive/Restore

```ruby
# app/policies/concerns/archivable.rb
module Archivable
  def archive?
    owner_or_admin? && !archived?
  end

  def restore?
    owner_or_admin? && archived?
  end

  def archived?
    record.respond_to?(:archived?) && record.archived?
  end

  # Can only update non-archived records
  def update?
    !archived? && owner_or_admin?
  end
end

# Usage
class ProjectPolicy < ApplicationPolicy
  include Archivable
end
```

### 6. Taggable - Tag Management

```ruby
# app/policies/concerns/taggable.rb
module Taggable
  def add_tag?
    contributor? || admin?
  end

  def remove_tag?
    add_tag?
  end

  def create_new_tag?
    admin?  # Only admins can create new tags
  end
end

# Usage
class PostPolicy < ApplicationPolicy
  include Taggable
end
```

### 7. Commentable - Comment Permissions

```ruby
# app/policies/concerns/commentable.rb
module Commentable
  def create_comment?
    logged_in? && record_visible?
  end

  def moderate_comments?
    owner? || admin? || moderator?
  end

  def delete_comment?
    admin? || moderator?
  end

  private

  def record_visible?
    # Override in including class if needed
    true
  end
end

# Usage
class PostPolicy < ApplicationPolicy
  include Commentable

  private

  def record_visible?
    record.published? || owner? || admin?
  end
end
```

## Advanced Patterns

### 1. Multiple Module Composition

```ruby
class PostPolicy < ApplicationPolicy
  include Ownable       # Adds owner?, owner_or_admin?
  include Publishable   # Adds publish?, unpublish?, show?
  include Timestamped   # Adds recent?, editable_period?
  include Commentable   # Adds comment management

  def update?
    owner_or_admin? && editable_period?
  end
end
```

### 2. Module Dependencies

```ruby
module Publishable
  # This module expects Ownable to be included
  def publish?
    raise "Include Ownable module first" unless respond_to?(:owner?)

    admin? || (contributor? && owner?)
  end
end

class PostPolicy < ApplicationPolicy
  include Ownable      # Include first
  include Publishable  # Depends on Ownable
end
```

### 3. Configurable Modules

```ruby
module Approvable
  def self.included(base)
    base.class_eval do
      # Make approval roles configurable
      def approval_roles
        @approval_roles ||= [:admin, :moderator]
      end

      def can_approve?
        user && approval_roles.any? { |role| user.send("#{role}?") }
      end
    end
  end
end
```

### 4. Attribute Modules

```ruby
module StandardAttributes
  def visible_attributes
    if admin?
      all_attributes
    elsif owner?
      owner_attributes
    else
      public_attributes
    end
  end

  def editable_attributes
    if admin?
      all_editable_attributes
    elsif owner?
      owner_editable_attributes
    else
      []
    end
  end

  private

  def all_attributes
    [:id, :title, :body, :user_id, :created_at, :updated_at, :published]
  end

  def owner_attributes
    [:id, :title, :body, :created_at, :updated_at, :published]
  end

  def public_attributes
    [:id, :title, :body, :created_at]
  end

  def all_editable_attributes
    [:title, :body, :published]
  end

  def owner_editable_attributes
    [:title, :body]
  end
end

class PostPolicy < ApplicationPolicy
  include StandardAttributes
end
```

### 5. Scope Modules

```ruby
module PublishedScope
  def self.included(base)
    base.const_get(:Scope).class_eval do
      def resolve
        if admin?
          scope.all
        else
          scope.where(published: true)
        end
      end
    end
  end
end

class PostPolicy < ApplicationPolicy
  include PublishedScope

  class Scope < ApplicationPolicy::Scope
    # resolve method is added by PublishedScope
  end
end
```

## Module Organization

### Directory Structure

```
app/
└── policies/
    ├── concerns/
    │   ├── ownable.rb
    │   ├── publishable.rb
    │   ├── timestamped.rb
    │   ├── approvable.rb
    │   ├── archivable.rb
    │   ├── taggable.rb
    │   ├── commentable.rb
    │   └── standard_attributes.rb
    ├── application_policy.rb
    ├── post_policy.rb
    ├── comment_policy.rb
    └── article_policy.rb
```

### Naming Conventions

- **Adjectives**: `Ownable`, `Publishable`, `Archivable`
- **Nouns**: `Ownership`, `Publishing`, `Timestamps`
- **Behavior**: `TimeBasedRules`, `ApprovalWorkflow`

Choose names that clearly describe the authorization behavior.

## Testing Composed Policies

### Testing Modules in Isolation

```ruby
# test/policies/concerns/ownable_test.rb
require 'test_helper'

class OwnableTest < ActiveSupport::TestCase
  # Create a test policy class
  class TestPolicy < ApplicationPolicy
    include Ownable
  end

  test "owner? returns true for record owner" do
    user = User.new(id: 1)
    record = OpenStruct.new(user_id: 1)
    policy = TestPolicy.new(user, record)

    assert policy.send(:owner?)
  end

  test "owner? returns false for non-owner" do
    user = User.new(id: 1)
    record = OpenStruct.new(user_id: 2)
    policy = TestPolicy.new(user, record)

    assert_not policy.send(:owner?)
  end

  test "owner_or_admin? returns true for owner" do
    user = User.new(id: 1, role: 'viewer')
    record = OpenStruct.new(user_id: 1)
    policy = TestPolicy.new(user, record)

    assert policy.send(:owner_or_admin?)
  end
end
```

### Testing Policies with Modules

```ruby
# test/policies/post_policy_test.rb
class PostPolicyTest < ActiveSupport::TestCase
  include SimpleAuthorize::TestHelpers

  test "includes Ownable module" do
    assert PostPolicy.included_modules.include?(Ownable)
  end

  test "uses Ownable's update? method" do
    owner = users(:author)
    post = Post.new(user_id: owner.id)
    policy = PostPolicy.new(owner, post)

    assert_permit_action policy, :update
  end

  test "includes Publishable module" do
    assert PostPolicy.included_modules.include?(Publishable)
  end

  test "uses Publishable's publish? method" do
    admin = users(:admin)
    post = posts(:draft)
    policy = PostPolicy.new(admin, post)

    assert_permit_action policy, :publish
  end
end
```

### Testing Module Interactions

```ruby
test "Ownable and Publishable work together" do
  author = users(:author)
  own_post = Post.new(user: author)
  policy = PostPolicy.new(author, own_post)

  # Can publish own post (Ownable + Publishable)
  assert_permit_action policy, :publish

  other_post = posts(:published)
  other_policy = PostPolicy.new(author, other_post)

  # Cannot publish others' posts
  assert_forbid_action other_policy, :publish
end
```

## Best Practices

### 1. Single Responsibility

Each module should handle one concern:

```ruby
# ✅ Good - focused on ownership
module Ownable
  def owner?
    record.user_id == user&.id
  end
end

# ❌ Bad - too many concerns
module Everything
  def owner?
    # ...
  end

  def publish?
    # ...
  end

  def moderate?
    # ...
  end
end
```

### 2. Document Module Dependencies

```ruby
# app/policies/concerns/publishable.rb
# Requires: Ownable module (for owner? method)
# Assumes: record responds to :published?
module Publishable
  def publish?
    admin? || (contributor? && owner?)
  end
end
```

### 3. Use Guard Clauses

```ruby
module Ownable
  def owner?
    return false unless record.respond_to?(:user_id)
    return false unless user

    record.user_id == user.id
  end
end
```

### 4. Provide Defaults

```ruby
module Publishable
  def publish?
    admin? || can_publish_content?
  end

  private

  # Override this in including class for custom logic
  def can_publish_content?
    contributor? && owner?
  end
end
```

### 5. Test Modules Independently

Create dedicated test files for each shared module.

### 6. Keep Modules Cohesive

Related authorization logic belongs together:

```ruby
# ✅ Good - cohesive
module Publishable
  def publish?
    # ...
  end

  def unpublish?
    # ...
  end

  def schedule_publish?
    # ...
  end
end

# ❌ Bad - unrelated concerns
module Mixed
  def publish?
    # ...
  end

  def update_tags?
    # ...
  end
end
```

## Real-World Example

```ruby
# app/policies/concerns/content_management.rb
module ContentManagement
  include Ownable
  include Publishable
  include Timestamped

  def update?
    return false if archived?
    owner_or_admin? && editable_period?
  end

  def destroy?
    admin? || (owner? && recent?)
  end

  def visible_attributes
    if admin?
      [:id, :title, :body, :user_id, :published, :created_at, :archived]
    elsif owner?
      [:id, :title, :body, :published, :created_at]
    else
      [:id, :title, :created_at]
    end
  end

  private

  def archived?
    record.respond_to?(:archived?) && record.archived?
  end
end

# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  include ContentManagement

  # Policy-specific customization
  def create?
    logged_in? && contributor?
  end
end

# app/policies/article_policy.rb
class ArticlePolicy < ApplicationPolicy
  include ContentManagement

  # Different creation rules for articles
  def create?
    admin?  # Only admins can create articles
  end
end
```

## Conclusion

Policy composition with Ruby modules:

✅ **Benefits:**
- Eliminates code duplication
- Makes authorization logic reusable
- Improves maintainability
- Organizes related concerns
- Simplifies testing

🎯 **Use When:**
- Multiple policies share authorization logic
- You have complex authorization patterns
- You want to organize related permissions
- You need to standardize behavior across policies

This pattern works today with SimpleAuthorize's existing architecture - no changes needed to the gem itself!
