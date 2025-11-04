require "test_helper"

# Comprehensive test for PostPolicy demonstrating all authorization scenarios
class PostPolicyTest < ActiveSupport::TestCase
  include SimpleAuthorize::TestHelpers

  def setup
    # Create users with different roles
    @admin = User.new(id: 1, role: "admin")
    @author = User.new(id: 2, role: "author")
    @moderator = User.new(id: 3, role: "moderator")
    @viewer = User.new(id: 4, role: "viewer")
    @guest = nil

    # Create posts
    @published_post = Post.new(id: 1, title: "Published Post", published: true, user_id: 2)
    @draft_post = Post.new(id: 2, title: "Draft Post", published: false, user_id: 2)
    @other_author_post = Post.new(id: 3, title: "Other Post", published: true, user_id: 999)
  end

  # INDEX ACTION TESTS

  test "index is public - anyone can access" do
    assert_permit_action PostPolicy.new(@guest, nil), :index
    assert_permit_action PostPolicy.new(@viewer, nil), :index
    assert_permit_action PostPolicy.new(@author, nil), :index
    assert_permit_action PostPolicy.new(@admin, nil), :index
  end

  # SHOW ACTION TESTS

  test "guests can view published posts" do
    policy = PostPolicy.new(@guest, @published_post)
    assert_permit_action policy, :show
  end

  test "guests cannot view draft posts" do
    policy = PostPolicy.new(@guest, @draft_post)
    assert_forbid_action policy, :show
  end

  test "authors can view their own drafts" do
    policy = PostPolicy.new(@author, @draft_post)
    assert_permit_action policy, :show
  end

  test "authors cannot view others' drafts" do
    draft = Post.new(id: 10, published: false, user_id: 999)
    policy = PostPolicy.new(@author, draft)
    assert_forbid_action policy, :show
  end

  test "moderators can view all posts including drafts" do
    assert_permit_action PostPolicy.new(@moderator, @draft_post), :show
    assert_permit_action PostPolicy.new(@moderator, @published_post), :show
  end

  test "admins can view all posts" do
    assert_permit_action PostPolicy.new(@admin, @draft_post), :show
    assert_permit_action PostPolicy.new(@admin, @published_post), :show
  end

  # CREATE ACTION TESTS

  test "guests cannot create posts" do
    policy = PostPolicy.new(@guest, Post.new)
    assert_forbid_action policy, :create
  end

  test "viewers cannot create posts" do
    policy = PostPolicy.new(@viewer, Post.new)
    assert_forbid_action policy, :create
  end

  test "authors can create posts" do
    policy = PostPolicy.new(@author, Post.new)
    assert_permit_action policy, :create
  end

  test "admins can create posts" do
    policy = PostPolicy.new(@admin, Post.new)
    assert_permit_action policy, :create
  end

  # UPDATE ACTION TESTS

  test "authors can update their own posts" do
    policy = PostPolicy.new(@author, @draft_post)
    assert_permit_action policy, :update
  end

  test "authors cannot update others' posts" do
    policy = PostPolicy.new(@author, @other_author_post)
    assert_forbid_action policy, :update
  end

  test "moderators cannot update posts" do
    policy = PostPolicy.new(@moderator, @published_post)
    assert_forbid_action policy, :update
  end

  test "admins can update any post" do
    policy = PostPolicy.new(@admin, @other_author_post)
    assert_permit_action policy, :update
  end

  # DESTROY ACTION TESTS

  test "authors can destroy their own posts" do
    policy = PostPolicy.new(@author, @draft_post)
    assert_permit_action policy, :destroy
  end

  test "authors cannot destroy others' posts" do
    policy = PostPolicy.new(@author, @other_author_post)
    assert_forbid_action policy, :destroy
  end

  test "admins can destroy any post" do
    policy = PostPolicy.new(@admin, @other_author_post)
    assert_permit_action policy, :destroy
  end

  # CUSTOM ACTION: PUBLISH

  test "authors can publish their own posts" do
    policy = PostPolicy.new(@author, @draft_post)
    assert_permit_action policy, :publish
  end

  test "authors cannot publish others' posts" do
    policy = PostPolicy.new(@author, @other_author_post)
    assert_forbid_action policy, :publish
  end

  test "admins can publish any post" do
    policy = PostPolicy.new(@admin, @draft_post)
    assert_permit_action policy, :publish
  end

  # PERMITTED ATTRIBUTES TESTS

  test "admins can edit all attributes" do
    policy = PostPolicy.new(@admin, @published_post)
    attrs = policy.permitted_attributes
    assert_includes attrs, :title
    assert_includes attrs, :body
    assert_includes attrs, :published
    assert_includes attrs, :user_id
  end

  test "authors can edit content but not published status of their posts" do
    policy = PostPolicy.new(@author, @draft_post)
    attrs = policy.permitted_attributes
    assert_includes attrs, :title
    assert_includes attrs, :body
    assert_not_includes attrs, :published
    assert_not_includes attrs, :user_id
  end

  test "authors get empty permitted attributes for others' posts" do
    policy = PostPolicy.new(@author, @other_author_post)
    assert_empty policy.permitted_attributes
  end

  # VISIBLE ATTRIBUTES TESTS

  test "admins can see all attributes" do
    policy = PostPolicy.new(@admin, @published_post)
    attrs = policy.visible_attributes
    assert_includes attrs, :id
    assert_includes attrs, :title
    assert_includes attrs, :published
    assert_includes attrs, :user_id
  end

  test "authors can see all attributes of their own posts" do
    policy = PostPolicy.new(@author, @draft_post)
    attrs = policy.visible_attributes
    assert_includes attrs, :id
    assert_includes attrs, :title
    assert_includes attrs, :published
    assert_includes attrs, :user_id
  end

  test "guests see limited attributes" do
    policy = PostPolicy.new(@guest, @published_post)
    attrs = policy.visible_attributes
    assert_includes attrs, :id
    assert_includes attrs, :title
    assert_includes attrs, :excerpt
    assert_not_includes attrs, :user_id
  end

  test "index shows limited attributes for everyone" do
    policy = PostPolicy.new(@admin, @published_post)
    attrs = policy.visible_attributes_for_index
    assert_includes attrs, :id
    assert_includes attrs, :title
    assert_equal 4, attrs.length  # Only show summary in index
  end

  # SCOPE TESTS

  test "guests see only published posts in scope" do
    # This would need actual ActiveRecord in a real test
    # Here we're just demonstrating the pattern
    scope = PostPolicy::Scope.new(@guest, Post)
    # In real test: assert_equal published_posts, scope.resolve
  end

  test "authors see published posts and their own drafts in scope" do
    scope = PostPolicy::Scope.new(@author, Post)
    # In real test: would verify SQL includes published OR user_id = author.id
  end

  test "admins see all posts in scope" do
    scope = PostPolicy::Scope.new(@admin, Post)
    # In real test: assert_equal all_posts, scope.resolve
  end
end
