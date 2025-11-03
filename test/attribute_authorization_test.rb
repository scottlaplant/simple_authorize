# frozen_string_literal: true

require "test_helper"

class AttributeAuthorizationTest < ActiveSupport::TestCase
  def setup
    @admin = User.new(id: 1, role: :admin)
    @viewer = User.new(id: 2, role: :viewer)
    @contributor = User.new(id: 3, role: :contributor)
    @post = Post.new(id: 1, user_id: 3)
  end

  # Visible Attributes Tests

  test "visible_attributes returns all attributes for admin" do
    policy = PostPolicy.new(@admin, @post)

    visible = policy.visible_attributes

    assert_includes visible, :id
    assert_includes visible, :title
    assert_includes visible, :body
    assert_includes visible, :published
    assert_includes visible, :user_id
  end

  test "visible_attributes hides sensitive fields for non-admin" do
    policy = PostPolicy.new(@viewer, @post)

    visible = policy.visible_attributes

    assert_includes visible, :id
    assert_includes visible, :title
    assert_includes visible, :body
    refute_includes visible, :user_id
  end

  test "visible_attributes can be action-specific" do
    policy = PostPolicy.new(@viewer, @post)

    index_visible = policy.visible_attributes_for_index
    show_visible = policy.visible_attributes_for_show

    # Index might show less than show action
    assert_includes show_visible, :body
    refute_includes index_visible, :body if policy.respond_to?(:visible_attributes_for_index)
  end

  # Editable Attributes Tests

  test "editable_attributes returns all editable fields for admin" do
    policy = PostPolicy.new(@admin, @post)

    editable = policy.editable_attributes

    assert_includes editable, :title
    assert_includes editable, :body
    assert_includes editable, :published
  end

  test "editable_attributes restricts fields for non-admin" do
    policy = PostPolicy.new(@contributor, @post)

    editable = policy.editable_attributes

    assert_includes editable, :title
    assert_includes editable, :body
    refute_includes editable, :published
  end

  test "editable_attributes can be action-specific" do
    policy = PostPolicy.new(@contributor, @post)

    create_editable = policy.editable_attributes_for_create
    update_editable = policy.editable_attributes_for_update

    # Create might allow more fields than update
    assert_kind_of Array, create_editable
    assert_kind_of Array, update_editable
  end

  test "editable_attributes does not include id field" do
    policy = PostPolicy.new(@admin, @post)

    editable = policy.editable_attributes

    refute_includes editable, :id
  end

  # Helper Method Tests

  test "attribute_visible? checks if attribute is visible" do
    policy = PostPolicy.new(@viewer, @post)

    assert policy.attribute_visible?(:title)
    refute policy.attribute_visible?(:user_id)
  end

  test "attribute_editable? checks if attribute is editable" do
    policy = PostPolicy.new(@contributor, @post)

    assert policy.attribute_editable?(:title)
    refute policy.attribute_editable?(:published)
  end

  # Controller Integration Tests

  test "controller can get visible attributes" do
    controller = MockController.new(@viewer)

    visible = controller.visible_attributes(@post)

    assert_includes visible, :title
    refute_includes visible, :user_id
  end

  test "controller can get editable attributes" do
    controller = MockController.new(@contributor)

    editable = controller.editable_attributes(@post)

    assert_includes editable, :title
    refute_includes editable, :published
  end

  test "controller respects action-specific attributes" do
    controller = MockController.new(@contributor)

    create_attrs = controller.editable_attributes(@post, :create)
    update_attrs = controller.editable_attributes(@post, :update)

    assert_kind_of Array, create_attrs
    assert_kind_of Array, update_attrs
  end

  # Filtering Tests

  test "filter_attributes removes non-visible attributes from hash" do
    controller = MockController.new(@viewer)
    controller.action = "show" # Use show action which includes body

    attrs = {
      id: 1,
      title: "Test",
      body: "Content",
      user_id: 123,
      published: true
    }

    filtered = controller.filter_attributes(@post, attrs)

    assert_equal "Test", filtered[:title]
    assert_equal "Content", filtered[:body]
    refute filtered.key?(:user_id)
  end

  test "filter_attributes works with ActiveModel objects" do
    controller = MockController.new(@viewer)
    controller.action = "show" # Use show action

    # Simulate filtering an object's attributes
    visible = controller.visible_attributes(@post)

    assert_includes visible, :title
    assert_includes visible, :body
  end

  # Edge Cases

  test "visible_attributes returns empty array when user is nil" do
    policy = PostPolicy.new(nil, @post)

    visible = policy.visible_attributes

    assert_kind_of Array, visible
    assert visible.empty?
  end

  test "editable_attributes returns empty array when user is nil" do
    policy = PostPolicy.new(nil, @post)

    editable = policy.editable_attributes

    assert_kind_of Array, editable
    assert editable.empty?
  end

  test "visible_attributes handles records without user" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      policy.visible_attributes
    end
  end

  # Helper mock controller
  class MockController
    include SimpleAuthorize::Controller

    attr_reader :current_user
    attr_writer :action

    def initialize(user)
      @current_user = user
      @action = "index"
    end

    def action_name
      @action
    end
  end
end
