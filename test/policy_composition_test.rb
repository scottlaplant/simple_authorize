# frozen_string_literal: true

require "test_helper"

# Test suite for policy composition using shared modules
class PolicyCompositionTest < ActiveSupport::TestCase
  include SimpleAuthorize::TestHelpers

  # Mock models for testing
  class User
    attr_accessor :id, :role

    def initialize(id:, role: "viewer")
      @id = id
      @role = role
    end

    def admin?
      @role == "admin"
    end

    def contributor?
      @role == "contributor"
    end

    def moderator?
      @role == "moderator"
    end
  end

  class Post
    attr_accessor :id, :user_id, :published, :created_at, :updated_at

    def initialize(id: 1, user_id: nil, published: false, created_at: Time.current, updated_at: nil)
      @id = id
      @user_id = user_id
      @published = published
      @created_at = created_at
      @updated_at = updated_at || created_at
    end

    def published?
      @published == true
    end
  end

  # Test policy using Ownable module
  class OwnableTestPolicy < SimpleAuthorize::Policy
    include SimpleAuthorize::PolicyModules::Ownable
  end

  # Test policy using Publishable module
  class PublishableTestPolicy < SimpleAuthorize::Policy
    include SimpleAuthorize::PolicyModules::Ownable
    include SimpleAuthorize::PolicyModules::Publishable
  end

  # Test policy using Timestamped module
  class TimestampedTestPolicy < SimpleAuthorize::Policy
    include SimpleAuthorize::PolicyModules::Ownable
    include SimpleAuthorize::PolicyModules::Timestamped
  end

  # Test policy using all modules together
  class ComposedTestPolicy < SimpleAuthorize::Policy
    include SimpleAuthorize::PolicyModules::Ownable
    include SimpleAuthorize::PolicyModules::Publishable
    include SimpleAuthorize::PolicyModules::Timestamped
  end

  def setup
    @admin = User.new(id: 1, role: "admin")
    @contributor = User.new(id: 2, role: "contributor")
    @viewer = User.new(id: 3, role: "viewer")
    @guest = nil

    @owned_post = Post.new(id: 1, user_id: 2)  # Owned by contributor
    @other_post = Post.new(id: 2, user_id: 99)
    @published_post = Post.new(id: 3, user_id: 2, published: true)
    @recent_post = Post.new(id: 4, user_id: 2, created_at: 1.hour.ago)
    @old_post = Post.new(id: 5, user_id: 2, created_at: 1.month.ago)
  end

  # Ownable Module Tests

  test "owner? returns true for record owner" do
    policy = OwnableTestPolicy.new(@contributor, @owned_post)
    assert policy.send(:owner?)
  end

  test "owner? returns false for non-owner" do
    policy = OwnableTestPolicy.new(@viewer, @owned_post)
    assert_not policy.send(:owner?)
  end

  test "owner? returns false for guest" do
    policy = OwnableTestPolicy.new(@guest, @owned_post)
    assert_not policy.send(:owner?)
  end

  test "owner_or_admin? returns true for owner" do
    policy = OwnableTestPolicy.new(@contributor, @owned_post)
    assert policy.send(:owner_or_admin?)
  end

  test "owner_or_admin? returns true for admin" do
    policy = OwnableTestPolicy.new(@admin, @other_post)
    assert policy.send(:owner_or_admin?)
  end

  test "owner_or_admin? returns false for non-owner non-admin" do
    policy = OwnableTestPolicy.new(@viewer, @other_post)
    assert_not policy.send(:owner_or_admin?)
  end

  test "Ownable provides update? based on ownership" do
    owner_policy = OwnableTestPolicy.new(@contributor, @owned_post)
    non_owner_policy = OwnableTestPolicy.new(@viewer, @owned_post)
    admin_policy = OwnableTestPolicy.new(@admin, @other_post)

    assert_permit_action owner_policy, :update
    assert_forbid_action non_owner_policy, :update
    assert_permit_action admin_policy, :update
  end

  test "Ownable provides destroy? based on ownership" do
    owner_policy = OwnableTestPolicy.new(@contributor, @owned_post)
    non_owner_policy = OwnableTestPolicy.new(@viewer, @owned_post)

    assert_permit_action owner_policy, :destroy
    assert_forbid_action non_owner_policy, :destroy
  end

  # Publishable Module Tests

  test "publish? allows admin to publish any post" do
    policy = PublishableTestPolicy.new(@admin, @owned_post)
    assert_permit_action policy, :publish
  end

  test "publish? allows contributor to publish own post" do
    policy = PublishableTestPolicy.new(@contributor, @owned_post)
    assert_permit_action policy, :publish
  end

  test "publish? denies contributor publishing others' posts" do
    policy = PublishableTestPolicy.new(@contributor, @other_post)
    assert_forbid_action policy, :publish
  end

  test "publish? denies viewer publishing" do
    policy = PublishableTestPolicy.new(@viewer, @owned_post)
    assert_forbid_action policy, :publish
  end

  test "unpublish? uses same rules as publish?" do
    policy = PublishableTestPolicy.new(@contributor, @owned_post)
    assert_permit_action policy, :unpublish
  end

  test "schedule? uses same rules as publish?" do
    policy = PublishableTestPolicy.new(@contributor, @owned_post)
    assert_permit_action policy, :schedule
  end

  test "show? allows viewing published posts" do
    policy = PublishableTestPolicy.new(@viewer, @published_post)
    assert_permit_action policy, :show
  end

  test "show? denies viewing unpublished posts by non-owners" do
    unpublished = Post.new(user_id: 99, published: false)
    policy = PublishableTestPolicy.new(@viewer, unpublished)
    assert_forbid_action policy, :show
  end

  test "show? allows owner to view own unpublished posts" do
    unpublished = Post.new(user_id: 2, published: false)
    policy = PublishableTestPolicy.new(@contributor, unpublished)
    assert_permit_action policy, :show
  end

  # Timestamped Module Tests

  test "recent? returns true for recent posts" do
    policy = TimestampedTestPolicy.new(@contributor, @recent_post)
    assert policy.send(:recent?)
  end

  test "recent? returns false for old posts" do
    policy = TimestampedTestPolicy.new(@contributor, @old_post)
    assert_not policy.send(:recent?)
  end

  test "stale? is opposite of recent?" do
    recent_policy = TimestampedTestPolicy.new(@contributor, @recent_post)
    old_policy = TimestampedTestPolicy.new(@contributor, @old_post)

    assert_not recent_policy.send(:stale?)
    assert old_policy.send(:stale?)
  end

  test "editable_period? returns true within edit window" do
    very_recent = Post.new(user_id: 2, created_at: 30.minutes.ago)
    policy = TimestampedTestPolicy.new(@contributor, very_recent)
    assert policy.send(:editable_period?)
  end

  test "editable_period? returns false outside edit window" do
    policy = TimestampedTestPolicy.new(@contributor, @old_post)
    assert_not policy.send(:editable_period?)
  end

  test "recently_updated? checks updated_at" do
    post = Post.new(user_id: 2, created_at: 1.month.ago, updated_at: 1.day.ago)
    policy = TimestampedTestPolicy.new(@contributor, post)
    assert policy.send(:recently_updated?)
  end

  # Composed Policy Tests

  test "composed policy combines multiple modules" do
    policy = ComposedTestPolicy.new(@contributor, @owned_post)

    # Should have methods from all modules (checking protected methods)
    assert policy.send(:respond_to?, :owner?, true)           # Ownable (protected)
    assert policy.respond_to?(:publish?)         # Publishable (public)
    assert policy.send(:respond_to?, :recent?, true)          # Timestamped (protected)
    assert policy.send(:respond_to?, :editable_period?, true) # Timestamped (protected)
  end

  test "composed policy can use multiple module methods together" do
    very_recent_owned = Post.new(user_id: 2, created_at: 30.minutes.ago)
    policy = ComposedTestPolicy.new(@contributor, very_recent_owned)

    # Owner check from Ownable
    assert policy.send(:owner?)

    # Recent check from Timestamped
    assert policy.send(:recent?)

    # Editable period check from Timestamped
    assert policy.send(:editable_period?)

    # Publish check from Publishable
    assert_permit_action policy, :publish
  end

  test "modules don't conflict with each other" do
    policy = ComposedTestPolicy.new(@contributor, @owned_post)

    # Should be able to call methods from all modules without errors
    assert_nothing_raised do
      policy.send(:owner?)
      policy.send(:recent?)
      policy.publish?
      policy.show?
      policy.update?
    end
  end

  test "module methods can be overridden in policy" do
    override_policy_class = Class.new(SimpleAuthorize::Policy) do
      include SimpleAuthorize::PolicyModules::Ownable

      def update?
        false  # Override Ownable's update?
      end
    end

    policy = override_policy_class.new(@contributor, @owned_post)
    assert_forbid_action policy, :update  # Should use overridden method
  end

  test "super can be used to call module methods" do
    super_policy_class = Class.new(SimpleAuthorize::Policy) do
      include SimpleAuthorize::PolicyModules::Ownable

      def update?
        super || user&.id == 1  # Allow if owner OR user id is 1
      end
    end

    owner_policy = super_policy_class.new(@contributor, @owned_post)
    special_user = User.new(id: 1, role: "viewer")
    special_policy = super_policy_class.new(special_user, @other_post)

    assert_permit_action owner_policy, :update  # Allowed via super
    assert_permit_action special_policy, :update  # Allowed via special condition
  end

  test "multiple modules can be used in one policy" do
    assert ComposedTestPolicy.included_modules.include?(SimpleAuthorize::PolicyModules::Ownable)
    assert ComposedTestPolicy.included_modules.include?(SimpleAuthorize::PolicyModules::Publishable)
    assert ComposedTestPolicy.included_modules.include?(SimpleAuthorize::PolicyModules::Timestamped)
  end
end
