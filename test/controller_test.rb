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
    @request = OpenStruct.new(referrer: nil, url: "http://example.com/test")
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

  # Test user_not_authorized alias
  test "user_not_authorized calls handle_unauthorized" do
    @controller.user_not_authorized
    assert_equal "/", @controller.redirected_to
  end

  # Test API detection
  test "api_request? detects JSON format" do
    @controller.request = OpenStruct.new(
      format: OpenStruct.new(json?: true, xml?: false, html?: false),
      headers: {}
    )
    assert @controller.api_request?
  end

  test "api_request? detects XML format" do
    @controller.request = OpenStruct.new(
      format: OpenStruct.new(json?: false, xml?: true, html?: false),
      headers: {}
    )
    assert @controller.api_request?
  end

  test "api_request? detects JSON in Accept header" do
    @controller.request = OpenStruct.new(
      format: OpenStruct.new(json?: false, xml?: false, html?: true),
      headers: {"Accept" => "application/json"}
    )
    assert @controller.api_request?
  end

  test "api_request? detects JSON in Content-Type header" do
    @controller.request = OpenStruct.new(
      format: OpenStruct.new(json?: false, xml?: false, html?: true),
      headers: {"Content-Type" => "application/json"}
    )
    assert @controller.api_request?
  end

  test "api_request? returns false for HTML" do
    @controller.request = OpenStruct.new(
      format: OpenStruct.new(json?: false, xml?: false, html?: true),
      headers: {}
    )
    refute @controller.api_request?
  end

  # Test safe_referrer_path edge cases
  test "safe_referrer_path handles nil referrer" do
    @controller.request.referrer = nil
    assert_nil @controller.safe_referrer_path
  end

  test "safe_referrer_path handles invalid URI" do
    @controller.request.referrer = "not a valid uri!!!"
    assert_nil @controller.safe_referrer_path
  end

  # Test filter_attributes
  test "filter_attributes returns only visible attributes" do
    @controller.action_name = "show"
    attributes = {id: 1, title: "Test", body: "Body", secret: "Secret"}
    filtered = @controller.filter_attributes(@post, attributes)

    # Admin can see id, title, body, published, user_id for show action
    assert filtered.key?(:id)
    assert filtered.key?(:title)
    assert filtered.key?(:body)
    refute filtered.key?(:secret)
  end

  test "filter_attributes respects role-based visibility" do
    @controller.current_user = @viewer
    @controller.action_name = "index"
    attributes = {id: 1, title: "Test", body: "Body", user_id: 1, published: true}
    filtered = @controller.filter_attributes(@post, attributes)

    # For index action, viewer can't see body or user_id
    assert filtered.key?(:id)
    assert filtered.key?(:title)
    refute filtered.key?(:user_id)
  end

  # Test policy_params
  test "policy_params builds permitted params from policy" do
    @controller.params = ActionController::Parameters.new({
                                                             post: {title: "Test", body: "Body", secret: "Secret"}
                                                           })

    permitted = @controller.policy_params(@post)
    assert_equal "Test", permitted[:title]
    assert_equal "Body", permitted[:body]
    refute permitted.key?(:secret)
  end

  test "policy_params accepts custom param key" do
    @controller.params = ActionController::Parameters.new({
                                                             article: {title: "Test", body: "Body"}
                                                           })

    permitted = @controller.policy_params(@post, :article)
    assert_equal "Test", permitted[:title]
  end

  # Test api_error_response
  test "api_error_response builds structured error response" do
    response = @controller.api_error_response(message: "Custom error", status: 403)

    assert_equal 403, response[:status]
    assert_equal "application/json", response[:content_type]
    assert_equal "not_authorized", response[:body][:error]
    assert_equal "Custom error", response[:body][:message]
  end

  test "api_error_response includes optional details" do
    response = @controller.api_error_response(
      message: "Error",
      status: 401,
      details: {reason: "invalid_token"}
    )

    assert_equal 401, response[:status]
    assert_equal({reason: "invalid_token"}, response[:body][:details])
  end

  # Test visible_attributes
  test "visible_attributes returns policy visible attributes" do
    @controller.action_name = "show"
    attrs = @controller.visible_attributes(@post)
    assert_equal %i[id title body published user_id], attrs
  end

  test "visible_attributes for specific action" do
    attrs = @controller.visible_attributes(@post, :index)
    assert_equal %i[id title published], attrs
  end

  # Test editable_attributes
  test "editable_attributes returns policy editable attributes" do
    attrs = @controller.editable_attributes(@post)
    assert_equal %i[title body published], attrs
  end

  test "editable_attributes for specific action" do
    attrs = @controller.editable_attributes(@post, :create)
    assert_equal %i[title body published], attrs
  end

  # Test clear_policy_cache
  test "clear_policy_cache clears cached policies" do
    # Enable caching temporarily
    original_cache_setting = SimpleAuthorize.configuration.enable_policy_cache
    SimpleAuthorize.configuration.enable_policy_cache = true

    @controller.policy(@post)
    assert @controller.instance_variable_get(:@_policy_cache).present?

    @controller.clear_policy_cache
    assert_nil @controller.instance_variable_get(:@_policy_cache)
  ensure
    SimpleAuthorize.configuration.enable_policy_cache = original_cache_setting
  end

  # Test batch authorization
  test "authorize_all authorizes all records" do
    posts = [
      Post.new(id: 1, user_id: 1),
      Post.new(id: 2, user_id: 1)
    ]

    result = @controller.authorize_all(posts, :show?)
    assert_equal posts, result
    assert @controller.authorization_performed?
  end

  test "authorize_all raises on first unauthorized record" do
    @controller.current_user = @viewer
    posts = [
      Post.new(id: 1, user_id: 1),
      Post.new(id: 2, user_id: 1)
    ]

    assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      @controller.authorize_all(posts, :update?)
    end
  end

  test "authorized_records filters to only authorized records" do
    posts = [
      Post.new(id: 1, user_id: 1),
      Post.new(id: 2, user_id: 2),
      Post.new(id: 3, user_id: 3)
    ]

    # Viewer (id: 2) can only update their own post (id: 2, user_id: 2)
    @controller.current_user = @viewer
    authorized = @controller.authorized_records(posts, :update?)
    assert_equal 1, authorized.length
    assert_equal 2, authorized.first.id
  end

  test "partition_records splits authorized and unauthorized" do
    posts = [
      Post.new(id: 1, user_id: 1),
      Post.new(id: 2, user_id: 2)
    ]

    @controller.current_user = @admin
    authorized, unauthorized = @controller.partition_records(posts, :update?)
    assert_equal 2, authorized.length
    assert_empty unauthorized
  end

  # Test policy with namespace
  test "policy accepts namespace parameter" do
    # This tests the namespace path in the policy method
    policy = @controller.policy(@post, namespace: nil)
    assert_instance_of PostPolicy, policy
  end

  # Test handle_api_authorization_error
  test "handle_api_authorization_error with authenticated user returns 403" do
    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: :update?,
      record: @post,
      policy: PostPolicy.new(@admin, @post)
    )

    response = @controller.handle_api_authorization_error(error)
    assert_equal 403, response[:status]
    assert_equal "application/json", response[:content_type]
    assert_equal "not_authorized", response[:body][:error]
  end

  test "handle_api_authorization_error with nil user returns 401" do
    @controller.current_user = nil
    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: :show?,
      record: @post,
      policy: PostPolicy.new(nil, @post)
    )

    response = @controller.handle_api_authorization_error(error)
    assert_equal 401, response[:status]
  end

  test "handle_api_authorization_error includes details when configured" do
    original_setting = SimpleAuthorize.configuration.api_error_details
    SimpleAuthorize.configuration.api_error_details = true

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: :update?,
      record: @post,
      policy: PostPolicy.new(@admin, @post)
    )

    response = @controller.handle_api_authorization_error(error)
    assert_equal "update?", response[:body][:query]
    assert_equal "Post", response[:body][:record_type]
    assert_equal "PostPolicy", response[:body][:policy]
  ensure
    SimpleAuthorize.configuration.api_error_details = original_setting
  end

  # Test instrumentation
  test "authorize emits instrumentation event when enabled" do
    original_setting = SimpleAuthorize.configuration.enable_instrumentation
    SimpleAuthorize.configuration.enable_instrumentation = true

    events = []
    subscriber = ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      events << event
    end

    @controller.authorize(@post, :show?)

    assert_equal 1, events.length
    event_payload = events.first.payload
    assert_equal @admin, event_payload[:user]
    assert_equal @post, event_payload[:record]
    assert_equal "show?", event_payload[:query]
    assert event_payload[:authorized]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
    SimpleAuthorize.configuration.enable_instrumentation = original_setting
  end

  test "policy_scope emits instrumentation event when enabled" do
    original_setting = SimpleAuthorize.configuration.enable_instrumentation
    SimpleAuthorize.configuration.enable_instrumentation = true

    events = []
    subscriber = ActiveSupport::Notifications.subscribe("policy_scope.simple_authorize") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      events << event
    end

    posts_relation = Struct.new(:posts) do
      def model_name
        Post.model_name
      end
    end.new([Post.new])

    @controller.policy_scope(posts_relation)

    assert_equal 1, events.length
    event_payload = events.first.payload
    assert_equal @admin, event_payload[:user]
    assert_equal posts_relation, event_payload[:scope]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
    SimpleAuthorize.configuration.enable_instrumentation = original_setting
  end

  # Test policy caching with build_policy_cache_key
  test "policy uses cache when caching is enabled" do
    original_setting = SimpleAuthorize.configuration.enable_policy_cache
    SimpleAuthorize.configuration.enable_policy_cache = true

    policy1 = @controller.policy(@post)
    policy2 = @controller.policy(@post)

    # Should return same cached instance
    assert_equal policy1.object_id, policy2.object_id

    # Clear cache and get new instance
    @controller.clear_policy_cache
    policy3 = @controller.policy(@post)
    refute_equal policy1.object_id, policy3.object_id
  ensure
    SimpleAuthorize.configuration.enable_policy_cache = original_setting
  end

  # Test NotAuthorizedError with I18n
  test "NotAuthorizedError uses I18n default when no custom translation" do
    original_setting = SimpleAuthorize.configuration.i18n_enabled
    SimpleAuthorize.configuration.i18n_enabled = true

    # Clear any existing translations
    if defined?(I18n)
      I18n.backend.store_translations(:en, {
                                        simple_authorize: {
                                          errors: {
                                            not_authorized: "You are not authorized to perform this action"
                                          }
                                        }
                                      })
    end

    # Use a query that doesn't have a custom translation
    policy = PostPolicy.new(@viewer, @post)
    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: :publish?,
      record: @post,
      policy: policy
    )

    assert_includes error.message.downcase, "not authorized" if defined?(I18n)
  ensure
    SimpleAuthorize.configuration.i18n_enabled = original_setting
  end

  test "NotAuthorizedError with custom I18n translation" do
    original_setting = SimpleAuthorize.configuration.i18n_enabled
    SimpleAuthorize.configuration.i18n_enabled = true

    if defined?(I18n)
      I18n.backend.store_translations(:en, {
                                        simple_authorize: {
                                          policies: {
                                            post_policy: {
                                              update: {
                                                denied: "Custom: Cannot update this post"
                                              }
                                            }
                                          }
                                        }
                                      })
    end

    policy = PostPolicy.new(@viewer, @post)
    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: :update?,
      record: @post,
      policy: policy
    )

    if defined?(I18n)
      assert_equal "Custom: Cannot update this post", error.message
    end
  ensure
    SimpleAuthorize.configuration.i18n_enabled = original_setting
  end

  # Test handle_unauthorized with API requests
  test "handle_unauthorized renders JSON for API requests" do
    @controller.request = OpenStruct.new(
      format: OpenStruct.new(json?: true, xml?: false, html?: false),
      headers: {}
    )

    # Mock render method
    rendered = nil
    @controller.define_singleton_method(:render) do |options|
      rendered = options
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: :update?,
      record: @post,
      policy: PostPolicy.new(@admin, @post)
    )

    @controller.handle_unauthorized(error)

    assert rendered.present?
    assert_equal 403, rendered[:status]
    assert rendered[:json].present?
  end
end
