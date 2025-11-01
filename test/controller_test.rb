# frozen_string_literal: true

require "test_helper"
require "action_controller"

# Mock controller for testing
class TestController
  include SimpleAuthorize::Controller

  attr_accessor :action_name, :current_user, :params, :request
  attr_reader :flash, :redirected_to, :redirect_status

  def initialize
    @action_name = "index"
    @current_user = nil
    @params = {}
    @request = Struct.new(:referrer, :url).new(nil, "http://example.com/test")
    @flash = {}
    @redirected_to = nil
    @redirect_status = nil
  end

  def redirect_to(path, options = {})
    @redirected_to = path
    @redirect_status = options[:status]
  end

  def root_path
    "/"
  end

  # Make protected methods public for testing
  public :handle_unauthorized, :safe_referrer_path
end

class ControllerTest < ActiveSupport::TestCase
  def setup
    @controller = TestController.new
    @admin = User.new(id: 1, role: :admin)
    @viewer = User.new(id: 2, role: :viewer)
    @post = Post.new(id: 1, user_id: 1)
    @controller.current_user = @admin
  end

  # Test authorize
  test "authorize succeeds when policy allows" do
    result = @controller.authorize(@post, :show?)
    assert_equal @post, result
    assert @controller.authorization_performed?
  end

  test "authorize raises NotAuthorizedError when policy denies" do
    @controller.current_user = @viewer
    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      @controller.authorize(@post, :update?)
    end

    assert_equal :update?, error.query
    assert_equal @post, error.record
  end

  test "authorize uses action_name when query not provided" do
    @controller.action_name = "show"
    result = @controller.authorize(@post)
    assert_equal @post, result
  end

  # Test authorize!
  test "authorize! is alias for authorize" do
    result = @controller.authorize!(@post, :show?)
    assert_equal @post, result
  end

  # Test policy
  test "policy returns correct policy instance" do
    policy = @controller.policy(@post)
    assert_instance_of PostPolicy, policy
    assert_equal @admin, policy.user
    assert_equal @post, policy.record
  end

  test "policy accepts custom policy class" do
    custom_policy = Class.new(SimpleAuthorize::Policy)
    policy = @controller.policy(@post, policy_class: custom_policy)
    assert_instance_of custom_policy, policy
  end

  test "policy raises PolicyNotDefinedError for undefined policy" do
    undefined_model = Class.new
    error = assert_raises(SimpleAuthorize::Controller::PolicyNotDefinedError) do
      @controller.policy(undefined_model.new)
    end

    assert_match(/unable to find policy/, error.message)
  end

  # Test policy_scope
  test "policy_scope filters collection" do
    # Create mock relation that responds to model_name
    posts_relation = Struct.new(:posts) do
      def model_name
        Post.model_name
      end

      def select(&block)
        posts.select(&block)
      end
    end.new([
              Post.new(id: 1, published: true),
              Post.new(id: 2, published: false)
            ])

    @controller.current_user = @viewer
    scoped = @controller.policy_scope(posts_relation)

    assert_equal 1, scoped.length
    assert scoped.all?(&:published)
    assert @controller.policy_scoped?
  end

  # Test permitted_attributes
  test "permitted_attributes returns policy attributes" do
    attrs = @controller.permitted_attributes(@post)
    assert_equal %i[title body published], attrs
  end

  test "permitted_attributes for non-admin" do
    @controller.current_user = @viewer
    attrs = @controller.permitted_attributes(@post)
    assert_equal %i[title body], attrs
  end

  # Test verification
  test "verify_authorized raises when not authorized" do
    error = assert_raises(SimpleAuthorize::Controller::AuthorizationNotPerformedError) do
      @controller.verify_authorized
    end

    assert_match(/is missing authorization/, error.message)
  end

  test "verify_authorized passes when authorized" do
    @controller.authorize(@post, :show?)
    assert_nothing_raised do
      @controller.verify_authorized
    end
  end

  test "skip_authorization marks as authorized" do
    @controller.skip_authorization
    assert @controller.authorization_performed?
  end

  test "verify_policy_scoped raises when not scoped" do
    error = assert_raises(SimpleAuthorize::Controller::PolicyScopingNotPerformedError) do
      @controller.verify_policy_scoped
    end

    assert_match(/is missing policy scope/, error.message)
  end

  test "verify_policy_scoped passes when scoped" do
    # Create mock relation
    posts_relation = Struct.new(:posts) do
      def model_name
        Post.model_name
      end
    end.new([Post.new])

    @controller.policy_scope(posts_relation)
    assert_nothing_raised do
      @controller.verify_policy_scoped
    end
  end

  test "skip_policy_scope marks as scoped" do
    @controller.skip_policy_scope
    assert @controller.policy_scoped?
  end

  # Test authorize_headless
  test "authorize_headless succeeds for headless policy" do
    headless_policy = Class.new(SimpleAuthorize::Policy) do
      def index?
        user&.admin?
      end
    end

    result = @controller.authorize_headless(headless_policy)
    assert result
    assert @controller.authorization_performed?
  end

  test "authorize_headless raises when denied" do
    @controller.current_user = @viewer
    headless_policy = Class.new(SimpleAuthorize::Policy) do
      def index?
        user&.admin?
      end
    end

    assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      @controller.authorize_headless(headless_policy)
    end
  end

  # Test allowed_to?
  test "allowed_to? returns true when allowed" do
    assert @controller.allowed_to?(:show, @post)
  end

  test "allowed_to? returns false when not allowed" do
    @controller.current_user = @viewer
    refute @controller.allowed_to?(:update, @post)
  end

  test "allowed_to? returns false for undefined policy" do
    undefined_model = Class.new.new
    refute @controller.allowed_to?(:show, undefined_model)
  end

  # Test allowed_actions
  test "allowed_actions returns list of allowed CRUD actions" do
    actions = @controller.allowed_actions(@post)
    assert_includes actions, :show
    assert_includes actions, :index
  end

  # Test role helpers
  test "admin_user? returns true for admin" do
    assert @controller.admin_user?
  end

  test "admin_user? returns false for non-admin" do
    @controller.current_user = @viewer
    refute @controller.admin_user?
  end

  test "contributor_user? returns true for contributor" do
    @controller.current_user = User.new(role: :contributor)
    assert @controller.contributor_user?
  end

  test "viewer_user? returns true for viewer" do
    @controller.current_user = @viewer
    assert @controller.viewer_user?
  end

  # Test authorized_user
  test "authorized_user returns current_user by default" do
    assert_equal @admin, @controller.authorized_user
  end

  # Test reset_authorization
  test "reset_authorization clears tracking" do
    @controller.authorize(@post, :show?)
    assert @controller.authorization_performed?

    @controller.reset_authorization
    refute @controller.authorization_performed?
    refute @controller.policy_scoped?
  end

  # Test handle_unauthorized
  test "handle_unauthorized sets flash and redirects" do
    @controller.handle_unauthorized
    assert_equal "You are not authorized to perform this action.", @controller.flash[:alert]
    assert_equal "/", @controller.redirected_to
  end

  test "handle_unauthorized uses referrer when safe" do
    @controller.request.referrer = "http://example.com/posts"
    @controller.handle_unauthorized
    assert_equal "/posts", @controller.redirected_to
  end

  test "handle_unauthorized ignores external referrer" do
    @controller.request.referrer = "http://evil.com/phishing"
    @controller.handle_unauthorized
    assert_equal "/", @controller.redirected_to
  end

  # Test NotAuthorizedError structure
  test "NotAuthorizedError stores query, record, and policy" do
    @controller.current_user = @viewer
    @controller.authorize(@post, :update?)
  rescue SimpleAuthorize::Controller::NotAuthorizedError => e
    assert_equal :update?, e.query
    assert_equal @post, e.record
    assert_instance_of PostPolicy, e.policy
  end

  test "NotAuthorizedError accepts string message" do
    error = SimpleAuthorize::Controller::NotAuthorizedError.new("Custom message")
    assert_equal "Custom message", error.message
  end
end
