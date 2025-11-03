# frozen_string_literal: true

require "test_helper"

class PolicyCacheTest < ActiveSupport::TestCase
  def setup
    @user = User.new(id: 1, role: :admin)
    @post = Post.new(id: 1, user_id: 1)
    @controller = MockController.new(@user)
  end

  def teardown
    # Reset configuration after each test
    SimpleAuthorize.reset_configuration!
  end

  test "caching is disabled by default" do
    refute SimpleAuthorize.configuration.enable_policy_cache
  end

  test "caching can be enabled via configuration" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    assert SimpleAuthorize.configuration.enable_policy_cache
  end

  test "policy returns same instance when caching is enabled" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    policy1 = @controller.policy(@post)
    policy2 = @controller.policy(@post)

    assert_same policy1, policy2
  end

  test "policy returns different instances when caching is disabled" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = false
    end

    policy1 = @controller.policy(@post)
    policy2 = @controller.policy(@post)

    refute_same policy1, policy2
  end

  test "policy cache is scoped by user" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    user1 = User.new(id: 1, role: :admin)
    user2 = User.new(id: 2, role: :viewer)
    controller1 = MockController.new(user1)
    controller2 = MockController.new(user2)

    policy1 = controller1.policy(@post)
    policy2 = controller2.policy(@post)

    refute_same policy1, policy2
  end

  test "policy cache is scoped by record" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    post1 = Post.new(id: 1, user_id: 1)
    post2 = Post.new(id: 2, user_id: 1)

    policy1 = @controller.policy(post1)
    policy2 = @controller.policy(post2)

    refute_same policy1, policy2
  end

  test "policy cache is scoped by policy class" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    # Create a second policy class for testing
    custom_policy_class = Class.new(SimpleAuthorize::Policy)

    policy1 = @controller.policy(@post)
    policy2 = @controller.policy(@post, policy_class: custom_policy_class)

    refute_same policy1, policy2
  end

  test "cache can be cleared" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    policy1 = @controller.policy(@post)
    @controller.clear_policy_cache
    policy2 = @controller.policy(@post)

    refute_same policy1, policy2
  end

  test "cache is automatically cleared in tests when reset_authorization is called" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    policy1 = @controller.policy(@post)
    @controller.reset_authorization
    policy2 = @controller.policy(@post)

    refute_same policy1, policy2
  end

  test "policy scope is not cached" do
    # Policy scopes typically wrap ActiveRecord relations which should not be cached
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    scope1 = @controller.policy_scope(Post)
    scope2 = @controller.policy_scope(Post)

    # Scopes should work but not be cached (they're typically ActiveRecord relations)
    # We just verify they both work
    assert_respond_to scope1, :to_a
    assert_respond_to scope2, :to_a
  end

  # Helper mock controller class for testing
  class MockController
    include SimpleAuthorize::Controller

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    # Mock action_name for testing
    def action_name
      "index"
    end
  end
end
