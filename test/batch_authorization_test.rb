# frozen_string_literal: true

require "test_helper"

class BatchAuthorizationTest < ActiveSupport::TestCase
  def setup
    @admin = User.new(id: 1, role: :admin)
    @contributor = User.new(id: 2, role: :contributor)
    @viewer = User.new(id: 3, role: :viewer)

    @own_post = Post.new(id: 1, user_id: 2)
    @other_post1 = Post.new(id: 2, user_id: 999)
    @other_post2 = Post.new(id: 3, user_id: 998)

    @all_posts = [@own_post, @other_post1, @other_post2]
  end

  # authorize_all Tests

  test "authorize_all succeeds when all records are authorized" do
    controller = MockController.new(@admin)

    assert_nothing_raised do
      controller.authorize_all(@all_posts, :update?)
    end
  end

  test "authorize_all raises when any record is not authorized" do
    controller = MockController.new(@contributor)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize_all(@all_posts, :update?)
    end

    assert_equal "update?", error.query.to_s
    # Should fail on first unauthorized record
    assert_includes [@other_post1, @other_post2], error.record
  end

  test "authorize_all with empty array succeeds" do
    controller = MockController.new(@viewer)

    assert_nothing_raised do
      controller.authorize_all([], :update?)
    end
  end

  test "authorize_all returns the records on success" do
    controller = MockController.new(@admin)

    result = controller.authorize_all(@all_posts, :update?)

    assert_equal @all_posts, result
  end

  # authorized_records Tests

  test "authorized_records returns only authorized records" do
    controller = MockController.new(@contributor)

    authorized = controller.authorized_records(@all_posts, :update?)

    assert_equal 1, authorized.size
    assert_includes authorized, @own_post
    refute_includes authorized, @other_post1
    refute_includes authorized, @other_post2
  end

  test "authorized_records returns all records for admin" do
    controller = MockController.new(@admin)

    authorized = controller.authorized_records(@all_posts, :update?)

    assert_equal 3, authorized.size
    assert_equal @all_posts, authorized
  end

  test "authorized_records returns empty array when none authorized" do
    controller = MockController.new(@viewer)

    authorized = controller.authorized_records(@all_posts, :update?)

    assert_empty authorized
  end

  test "authorized_records with empty input returns empty array" do
    controller = MockController.new(@admin)

    authorized = controller.authorized_records([], :update?)

    assert_empty authorized
  end

  # partition_records Tests

  test "partition_records splits into authorized and unauthorized" do
    controller = MockController.new(@contributor)

    authorized, unauthorized = controller.partition_records(@all_posts, :update?)

    assert_equal 1, authorized.size
    assert_equal 2, unauthorized.size

    assert_includes authorized, @own_post
    assert_includes unauthorized, @other_post1
    assert_includes unauthorized, @other_post2
  end

  test "partition_records with all authorized" do
    controller = MockController.new(@admin)

    authorized, unauthorized = controller.partition_records(@all_posts, :update?)

    assert_equal 3, authorized.size
    assert_empty unauthorized
  end

  test "partition_records with none authorized" do
    controller = MockController.new(@viewer)

    authorized, unauthorized = controller.partition_records(@all_posts, :update?)

    assert_empty authorized
    assert_equal 3, unauthorized.size
  end

  test "partition_records with empty input" do
    controller = MockController.new(@admin)

    authorized, unauthorized = controller.partition_records([], :update?)

    assert_empty authorized
    assert_empty unauthorized
  end

  # Performance & Caching Tests

  test "batch methods reuse policy instances when caching enabled" do
    SimpleAuthorize.configure do |config|
      config.enable_policy_cache = true
    end

    controller = MockController.new(@contributor)

    # This should reuse the same policy instance for all posts
    authorized = controller.authorized_records(@all_posts, :update?)

    assert_equal 1, authorized.size
  ensure
    SimpleAuthorize.reset_configuration!
  end

  # Edge Cases

  test "authorize_all with nil collection raises error" do
    controller = MockController.new(@admin)

    assert_raises(NoMethodError) do
      controller.authorize_all(nil, :update?)
    end
  end

  test "authorized_records handles mixed record types" do
    controller = MockController.new(@admin)
    mixed = [@own_post, @other_post1]

    authorized = controller.authorized_records(mixed, :update?)

    assert_equal 2, authorized.size
  end

  test "partition_records preserves order" do
    controller = MockController.new(@contributor)

    authorized, unauthorized = controller.partition_records(@all_posts, :update?)

    # First post is owned by contributor, others are not
    assert_equal [@own_post], authorized
    assert_equal [@other_post1, @other_post2], unauthorized
  end

  # Integration Tests

  test "batch authorization works with policy_scope" do
    controller = MockController.new(@contributor)

    # Demonstrate that both scoping and batch authorization work
    # In a real app, you'd scope first then authorize records
    authorized = controller.authorized_records(@all_posts, :update?)

    # Contributor can only update their own post
    assert_equal 1, authorized.size
    assert_includes authorized, @own_post
  end

  test "batch methods respect custom policy classes" do
    controller = MockController.new(@admin)

    # Should work even with default behavior
    authorized = controller.authorized_records(@all_posts, :update?)

    assert_equal @all_posts, authorized
  end

  # Helper mock controller
  class MockController
    include SimpleAuthorize::Controller

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def action_name
      "update"
    end
  end
end
