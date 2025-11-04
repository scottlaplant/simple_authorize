# Testing Guide

This guide covers testing strategies and best practices for SimpleAuthorize policies.

## Table of Contents

- [Testing Philosophy](#testing-philosophy)
- [Testing Policies](#testing-policies)
- [Testing Controllers](#testing-controllers)
- [Testing Views](#testing-views)
- [Test Helpers](#test-helpers)
- [RSpec Support](#rspec-support)
- [Testing Patterns](#testing-patterns)
- [Common Scenarios](#common-scenarios)

## Testing Philosophy

### What to Test

✅ **DO test:**
- Policy query methods (`update?`, `destroy?`, etc.)
- Attribute authorization (`visible_attributes`, `editable_attributes`)
- Scope resolution logic
- Custom authorization methods
- Edge cases and boundary conditions

❌ **DON'T test:**
- SimpleAuthorize's internal implementation
- The `authorize` and `policy_scope` controller methods (framework-level)
- Basic framework behavior

### Where to Test

**Policy Tests** (`test/policies/` or `spec/policies/`)
- Unit tests for authorization logic
- Test different user roles and permissions
- Test attribute visibility and editability

**Controller Tests** (`test/controllers/` or `spec/controllers/`)
- Integration tests for authorization in context
- Test that unauthorized actions are blocked
- Test proper error handling

**System/Feature Tests**
- End-to-end authorization flows
- UI visibility based on permissions

## Testing Policies

### Minitest Example

```ruby
# test/policies/post_policy_test.rb
require "test_helper"

class PostPolicyTest < ActiveSupport::TestCase
  include SimpleAuthorize::TestHelpers

  def setup
    @admin = users(:admin)
    @author = users(:author)
    @viewer = users(:viewer)
    @guest = nil

    @published_post = posts(:published)
    @draft_post = posts(:draft)
  end

  # Test CRUD actions
  test "admin can do everything" do
    policy = PostPolicy.new(@admin, @published_post)

    assert_permit_action policy, :index
    assert_permit_action policy, :show
    assert_permit_action policy, :create
    assert_permit_action policy, :update
    assert_permit_action policy, :destroy
  end

  test "author can manage own posts" do
    own_post = Post.new(user: @author)
    policy = PostPolicy.new(@author, own_post)

    assert_permit_action policy, :update
    assert_permit_action policy, :destroy
  end

  test "author cannot manage others posts" do
    other_post = Post.new(user: @admin)
    policy = PostPolicy.new(@author, other_post)

    assert_forbid_action policy, :update
    assert_forbid_action policy, :destroy
  end

  test "guests can view published posts" do
    policy = PostPolicy.new(@guest, @published_post)
    assert_permit_action policy, :show
  end

  test "guests cannot view drafts" do
    policy = PostPolicy.new(@guest, @draft_post)
    assert_forbid_action policy, :show
  end

  # Test custom actions
  test "author can publish own posts" do
    own_post = Post.new(user: @author)
    policy = PostPolicy.new(@author, own_post)

    assert_permit_action policy, :publish
  end

  # Test attribute visibility
  test "admin can see all attributes" do
    policy = PostPolicy.new(@admin, @published_post)

    assert_permit_viewing policy, :title
    assert_permit_viewing policy, :body
    assert_permit_viewing policy, :user_id
    assert_permit_viewing policy, :published
  end

  test "guest can only see public attributes" do
    policy = PostPolicy.new(@guest, @published_post)

    assert_permit_viewing policy, :title
    assert_forbid_viewing policy, :user_id
    assert_forbid_viewing policy, :published
  end

  # Test attribute editability
  test "author can edit content of own posts" do
    own_post = Post.new(user: @author)
    policy = PostPolicy.new(@author, own_post)

    assert_permit_editing policy, :title
    assert_permit_editing policy, :body
  end

  test "author cannot edit published status" do
    own_post = Post.new(user: @author)
    policy = PostPolicy.new(@author, own_post)

    assert_forbid_editing policy, :published
  end

  # Test scopes
  test "admin scope includes all posts" do
    scope = PostPolicy::Scope.new(@admin, Post.all)
    # In a real test with database:
    # assert_equal Post.count, scope.resolve.count
  end

  test "guest scope includes only published posts" do
    scope = PostPolicy::Scope.new(@guest, Post.all)
    # In a real test with database:
    # assert_equal Post.where(published: true).count, scope.resolve.count
  end
end
```

### RSpec Example

```ruby
# spec/policies/post_policy_spec.rb
require "rails_helper"

RSpec.describe PostPolicy do
  subject { described_class.new(user, post) }

  let(:post) { create(:post) }

  context "as an admin" do
    let(:user) { create(:user, :admin) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }

    it { should permit_viewing(:title) }
    it { should permit_viewing(:user_id) }
    it { should permit_editing(:published) }
  end

  context "as an author" do
    let(:user) { create(:user, :author) }

    context "with own post" do
      let(:post) { create(:post, user: user) }

      it { should permit_action(:update) }
      it { should permit_action(:destroy) }
      it { should permit_viewing(:user_id) }
      it { should permit_editing(:title) }
    end

    context "with other's post" do
      let(:post) { create(:post) }

      it { should forbid_action(:update) }
      it { should forbid_action(:destroy) }
    end
  end

  context "as a guest" do
    let(:user) { nil }

    context "with published post" do
      let(:post) { create(:post, :published) }

      it { should permit_action(:show) }
      it { should forbid_action(:update) }
    end

    context "with draft post" do
      let(:post) { create(:post, :draft) }

      it { should forbid_action(:show) }
    end
  end

  describe "scope" do
    let!(:published_posts) { create_list(:post, 3, :published) }
    let!(:draft_posts) { create_list(:post, 2, :draft) }

    context "as admin" do
      let(:user) { create(:user, :admin) }

      it "returns all posts" do
        scope = PostPolicy::Scope.new(user, Post.all)
        expect(scope.resolve.count).to eq(5)
      end
    end

    context "as guest" do
      let(:user) { nil }

      it "returns only published posts" do
        scope = PostPolicy::Scope.new(user, Post.all)
        expect(scope.resolve.count).to eq(3)
      end
    end
  end
end
```

## Testing Controllers

### Minitest Controller Tests

```ruby
# test/controllers/posts_controller_test.rb
require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:published)
    @admin = users(:admin)
    @viewer = users(:viewer)
  end

  # Test authorization is enforced
  test "should require authorization for update" do
    sign_in @viewer

    patch post_url(@post), params: { post: { title: "Hacked" } }

    assert_response :redirect
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "admin can update posts" do
    sign_in @admin

    patch post_url(@post), params: { post: { title: "Updated" } }

    assert_response :redirect
    @post.reload
    assert_equal "Updated", @post.title
  end

  # Test scoping works correctly
  test "index shows only authorized posts" do
    draft_post = posts(:draft)

    sign_in @viewer
    get posts_url

    assert_response :success
    assert_select "article#post_#{@post.id}"  # Published post visible
    assert_select "article#post_#{draft_post.id}", count: 0  # Draft not visible
  end

  # Test authorization verification
  test "raises error if authorization not performed" do
    # If using AutoVerify module
    assert_raises SimpleAuthorize::Controller::AuthorizationNotPerformedError do
      get unprotected_action_url  # Action that doesn't call authorize
    end
  end
end
```

### RSpec Controller Tests

```ruby
# spec/controllers/posts_controller_spec.rb
require "rails_helper"

RSpec.describe PostsController, type: :controller do
  let(:post) { create(:post) }

  describe "GET #index" do
    it "scopes posts correctly" do
      sign_in create(:user)
      get :index
      expect(assigns(:posts)).to be_present
    end
  end

  describe "GET #show" do
    context "when authorized" do
      before { sign_in post.user }

      it "shows the post" do
        get :show, params: { id: post.id }
        expect(response).to be_successful
      end
    end

    context "when not authorized" do
      before { sign_in create(:user) }

      it "denies access" do
        draft = create(:post, :draft)
        expect {
          get :show, params: { id: draft.id }
        }.to raise_error(SimpleAuthorize::Controller::NotAuthorizedError)
      end
    end
  end

  describe "PATCH #update" do
    context "as owner" do
      before { sign_in post.user }

      it "updates the post" do
        patch :update, params: { id: post.id, post: { title: "New Title" } }
        expect(post.reload.title).to eq("New Title")
      end
    end

    context "as non-owner" do
      before { sign_in create(:user) }

      it "denies access" do
        expect {
          patch :update, params: { id: post.id, post: { title: "Hacked" } }
        }.to raise_error(SimpleAuthorize::Controller::NotAuthorizedError)
      end
    end
  end
end
```

## Testing Views

### View Tests with Capybara

```ruby
# spec/features/post_management_spec.rb
require "rails_helper"

RSpec.feature "Post Management", type: :feature do
  let(:post) { create(:post) }

  context "as post owner" do
    before do
      sign_in post.user
      visit post_path(post)
    end

    it "shows edit link" do
      expect(page).to have_link("Edit")
    end

    it "shows delete link" do
      expect(page).to have_link("Delete")
    end
  end

  context "as viewer" do
    before do
      sign_in create(:user, :viewer)
      visit post_path(post)
    end

    it "hides edit link" do
      expect(page).not_to have_link("Edit")
    end

    it "hides delete link" do
      expect(page).not_to have_link("Delete")
    end
  end
end
```

## Test Helpers

### Available Minitest Helpers

```ruby
include SimpleAuthorize::TestHelpers

# Action permissions
assert_permit_action(policy, :update)
assert_forbid_action(policy, :destroy)

# Attribute visibility
assert_permit_viewing(policy, :email)
assert_forbid_viewing(policy, :password)

# Attribute editability
assert_permit_editing(policy, :title)
assert_forbid_editing(policy, :id)
```

### Available RSpec Matchers

```ruby
# In rails_helper.rb or spec_helper.rb
RSpec.configure do |config|
  config.include SimpleAuthorize::RSpecMatchers
end

# In specs
it { should permit_action(:update) }
it { should forbid_action(:destroy) }

it { should permit_viewing(:email) }
it { should forbid_viewing(:password) }

it { should permit_editing(:title) }
it { should forbid_editing(:id) }
```

## Testing Patterns

### Testing Multiple Roles

```ruby
# Use shared examples for role-based testing
RSpec.shared_examples "read-only access" do
  it { should permit_action(:index) }
  it { should permit_action(:show) }
  it { should forbid_action(:create) }
  it { should forbid_action(:update) }
  it { should forbid_action(:destroy) }
end

RSpec.describe PostPolicy do
  subject { described_class.new(user, post) }
  let(:post) { create(:post) }

  context "as viewer" do
    let(:user) { create(:user, :viewer) }
    it_behaves_like "read-only access"
  end

  context "as guest" do
    let(:user) { nil }
    it_behaves_like "read-only access"
  end
end
```

### Testing Permission Matrix

```ruby
# test/policies/post_policy_test.rb
class PostPolicyTest < ActiveSupport::TestCase
  include SimpleAuthorize::TestHelpers

  ROLES = [:admin, :author, :viewer, :guest].freeze
  ACTIONS = [:index, :show, :create, :update, :destroy].freeze

  # Define permission matrix
  PERMISSIONS = {
    admin: [:index, :show, :create, :update, :destroy],
    author: [:index, :show, :create],  # + update/destroy own
    viewer: [:index, :show],
    guest: [:index, :show]  # published only
  }.freeze

  ROLES.each do |role|
    ACTIONS.each do |action|
      test "#{role} permissions for #{action}" do
        user = role == :guest ? nil : users(role)
        post = posts(:published)
        policy = PostPolicy.new(user, post)

        if PERMISSIONS[role].include?(action)
          assert_permit_action policy, action
        else
          assert_forbid_action policy, action
        end
      end
    end
  end
end
```

### Testing with Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    role { "viewer" }

    trait :admin do
      role { "admin" }
    end

    trait :author do
      role { "author" }
    end
  end
end

# spec/factories/posts.rb
FactoryBot.define do
  factory :post do
    association :user
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
    published { false }

    trait :published do
      published { true }
    end

    trait :draft do
      published { false }
    end
  end
end

# Usage in tests
let(:admin) { create(:user, :admin) }
let(:published_post) { create(:post, :published) }
```

## Common Scenarios

### Testing Ownership

```ruby
test "users can edit their own posts" do
  user = users(:author)
  own_post = Post.create(user: user, title: "My Post")
  other_post = posts(:published)  # Belongs to someone else

  policy_own = PostPolicy.new(user, own_post)
  policy_other = PostPolicy.new(user, other_post)

  assert_permit_action policy_own, :update
  assert_forbid_action policy_other, :update
end
```

### Testing Status-Based Authorization

```ruby
test "can only cancel pending orders" do
  user = users(:customer)
  pending_order = orders(:pending)
  shipped_order = orders(:shipped)

  pending_policy = OrderPolicy.new(user, pending_order)
  shipped_policy = OrderPolicy.new(user, shipped_order)

  assert_permit_action pending_policy, :cancel
  assert_forbid_action shipped_policy, :cancel
end
```

### Testing Multi-Tenancy

```ruby
test "users cannot access other tenants' data" do
  tenant_a = tenants(:acme)
  tenant_b = tenants(:widgets)

  user_a = User.create(tenant: tenant_a, role: "admin")
  project_b = Project.create(tenant: tenant_b)

  policy = ProjectPolicy.new(user_a, project_b)

  assert_forbid_action policy, :show
  assert_forbid_action policy, :update
end
```

### Testing Scopes with Database

```ruby
test "scope filters by tenant" do
  tenant = tenants(:acme)
  user = User.create(tenant: tenant, role: "member")

  # Create projects in different tenants
  own_projects = create_list(:project, 3, tenant: tenant)
  other_projects = create_list(:project, 2, tenant: tenants(:widgets))

  scope = ProjectPolicy::Scope.new(user, Project.all)
  resolved = scope.resolve

  assert_equal 3, resolved.count
  assert_equal own_projects.map(&:id).sort, resolved.pluck(:id).sort
end
```

### Testing Permitted Attributes

```ruby
test "permitted attributes vary by role" do
  admin = users(:admin)
  author = users(:author)
  post = posts(:published)

  admin_policy = PostPolicy.new(admin, post)
  author_policy = PostPolicy.new(author, post)

  admin_attrs = admin_policy.permitted_attributes
  author_attrs = author_policy.permitted_attributes

  assert_includes admin_attrs, :published
  assert_not_includes author_attrs, :published
end
```

## Test Organization

### Directory Structure

```
test/
├── policies/
│   ├── post_policy_test.rb
│   ├── comment_policy_test.rb
│   └── user_policy_test.rb
├── controllers/
│   └── posts_controller_test.rb
└── integration/
    └── authorization_flow_test.rb

spec/
├── policies/
│   ├── post_policy_spec.rb
│   └── comment_policy_spec.rb
├── controllers/
│   └── posts_controller_spec.rb
├── features/
│   └── post_management_spec.rb
└── support/
    └── authorization_helpers.rb
```

### Test Setup Helpers

```ruby
# test/support/authorization_helpers.rb
module AuthorizationHelpers
  def assert_authorized(&block)
    assert_nothing_raised(&block)
  end

  def assert_not_authorized(&block)
    assert_raises SimpleAuthorize::Controller::NotAuthorizedError, &block
  end

  def sign_in(user)
    session[:user_id] = user.id
  end

  def sign_out
    session[:user_id] = nil
  end
end

# test/test_helper.rb
class ActiveSupport::TestCase
  include AuthorizationHelpers
  include SimpleAuthorize::TestHelpers
end
```

## Best Practices

1. **Test all roles** - Ensure every role has expected permissions
2. **Test edge cases** - Nil users, missing records, boundary conditions
3. **Test custom actions** - Don't forget non-CRUD actions like `publish?`
4. **Test scopes** - Verify collections are filtered correctly
5. **Test attributes** - Check visibility and editability
6. **Use factories** - Create consistent test data
7. **Use helpers** - Leverage built-in test helpers
8. **Test integration** - Ensure authorization works in controllers
9. **Test UI** - Verify links/buttons are shown/hidden correctly
10. **Keep tests fast** - Mock external dependencies

## Conclusion

Comprehensive testing ensures your authorization logic is correct and secure. Use the built-in test helpers, test all roles and edge cases, and organize your tests for maintainability.
