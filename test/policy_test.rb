# frozen_string_literal: true

require "test_helper"

class PolicyTest < ActiveSupport::TestCase
  def setup
    @admin = User.new(id: 1, role: :admin)
    @contributor = User.new(id: 2, role: :contributor)
    @viewer = User.new(id: 3, role: :viewer)
    @post = Post.new(id: 1, user_id: 2, published: true)
  end

  # Test base policy defaults
  test "base policy denies everything by default" do
    policy = SimpleAuthorize::Policy.new(@viewer, @post)

    refute policy.index?
    refute policy.show?
    refute policy.create?
    refute policy.update?
    refute policy.destroy?
  end

  # Test index
  test "index? allows everyone" do
    assert PostPolicy.new(@admin, @post).index?
    assert PostPolicy.new(@contributor, @post).index?
    assert PostPolicy.new(@viewer, @post).index?
    assert PostPolicy.new(nil, @post).index?
  end

  # Test show
  test "show? allows everyone" do
    assert PostPolicy.new(@admin, @post).show?
    assert PostPolicy.new(@contributor, @post).show?
    assert PostPolicy.new(@viewer, @post).show?
  end

  # Test create
  test "create? allows admin and contributor" do
    assert PostPolicy.new(@admin, Post.new).create?
    assert PostPolicy.new(@contributor, Post.new).create?
  end

  test "create? denies viewer" do
    refute PostPolicy.new(@viewer, Post.new).create?
  end

  test "create? denies nil user" do
    refute PostPolicy.new(nil, Post.new).create?
  end

  # Test update
  test "update? allows admin for any post" do
    assert PostPolicy.new(@admin, @post).update?
  end

  test "update? allows owner" do
    owner_post = Post.new(user_id: @contributor.id)
    assert PostPolicy.new(@contributor, owner_post).update?
  end

  test "update? denies non-owner non-admin" do
    viewer_post = Post.new(user_id: @viewer.id)
    refute PostPolicy.new(@contributor, viewer_post).update?
  end

  # Test destroy
  test "destroy? allows admin for any post" do
    assert PostPolicy.new(@admin, @post).destroy?
  end

  test "destroy? allows owner" do
    owner_post = Post.new(user_id: @contributor.id)
    assert PostPolicy.new(@contributor, owner_post).destroy?
  end

  test "destroy? denies non-owner non-admin" do
    viewer_post = Post.new(user_id: @viewer.id)
    refute PostPolicy.new(@contributor, viewer_post).destroy?
  end

  # Test custom action
  test "publish? allows admin" do
    assert PostPolicy.new(@admin, @post).publish?
  end

  test "publish? allows contributor if owner" do
    owner_post = Post.new(user_id: @contributor.id)
    assert PostPolicy.new(@contributor, owner_post).publish?
  end

  test "publish? denies contributor if not owner" do
    # @post has user_id: 2 which matches @contributor.id, so use admin's post
    admin_post = Post.new(user_id: @admin.id)
    refute PostPolicy.new(@contributor, admin_post).publish?
  end

  # Test helper methods
  test "admin? helper returns correct value" do
    admin_policy = PostPolicy.new(@admin, @post)
    viewer_policy = PostPolicy.new(@viewer, @post)

    assert admin_policy.send(:admin?)
    refute viewer_policy.send(:admin?)
  end

  test "contributor? helper returns correct value" do
    contributor_policy = PostPolicy.new(@contributor, @post)
    viewer_policy = PostPolicy.new(@viewer, @post)

    assert contributor_policy.send(:contributor?)
    refute viewer_policy.send(:contributor?)
  end

  test "owner? helper returns correct value" do
    owner_post = Post.new(user_id: @contributor.id)
    owner_policy = PostPolicy.new(@contributor, owner_post)

    # @post has user_id: 2 which matches @contributor.id, so use a different user
    different_post = Post.new(user_id: @admin.id)
    non_owner_policy = PostPolicy.new(@contributor, different_post)

    assert owner_policy.send(:owner?)
    refute non_owner_policy.send(:owner?)
  end

  test "logged_in? helper returns correct value" do
    logged_in_policy = PostPolicy.new(@viewer, @post)
    guest_policy = PostPolicy.new(nil, @post)

    assert logged_in_policy.send(:logged_in?)
    refute guest_policy.send(:logged_in?)
  end

  # Test permitted attributes
  test "permitted_attributes returns all attributes for admin" do
    policy = PostPolicy.new(@admin, @post)
    assert_equal %i[title body published], policy.permitted_attributes
  end

  test "permitted_attributes returns limited attributes for non-admin" do
    policy = PostPolicy.new(@contributor, @post)
    assert_equal %i[title body], policy.permitted_attributes
  end

  # Test new? and edit? aliases
  test "new? delegates to create?" do
    policy = PostPolicy.new(@contributor, Post.new)
    assert_equal policy.create?, policy.new?
  end

  test "edit? delegates to update?" do
    owner_post = Post.new(user_id: @contributor.id)
    policy = PostPolicy.new(@contributor, owner_post)
    assert_equal policy.update?, policy.edit?
  end

  # Test Scope
  test "scope resolves all posts for admin" do
    posts = [
      Post.new(id: 1, published: true),
      Post.new(id: 2, published: false)
    ]

    scope = PostPolicy::Scope.new(@admin, posts).resolve
    assert_equal 2, scope.length
  end

  test "scope resolves only published posts for non-admin" do
    posts = [
      Post.new(id: 1, published: true),
      Post.new(id: 2, published: false),
      Post.new(id: 3, published: true)
    ]

    scope = PostPolicy::Scope.new(@contributor, posts).resolve
    assert_equal 2, scope.length
    assert scope.all?(&:published)
  end

  test "base scope returns all by default" do
    # Create a mock ActiveRecord-like relation
    mock_relation = Class.new do
      attr_reader :posts

      def initialize
        @posts = [Post.new(id: 1), Post.new(id: 2)]
      end

      def all
        @posts
      end
    end.new

    scope = SimpleAuthorize::Policy::Scope.new(@viewer, mock_relation).resolve
    assert_equal 2, scope.length
    assert_equal mock_relation.posts.map(&:id), scope.map(&:id)
  end
end
