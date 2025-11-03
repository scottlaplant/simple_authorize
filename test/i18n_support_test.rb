# frozen_string_literal: true

require "test_helper"

class I18nSupportTest < ActiveSupport::TestCase
  def setup
    @admin = User.new(id: 1, role: :admin)
    @contributor = User.new(id: 2, role: :contributor)
    @viewer = User.new(id: 3, role: :viewer)
    @post = Post.new(id: 1, user_id: 2)

    # Set up I18n translations for testing
    I18n.backend.store_translations(:en, simple_authorize: {
                                      errors: {
                                        not_authorized: "You are not authorized to perform this action",
                                        not_authorized_api: "Not authorized",
                                        policy_not_defined: "Policy not found for %<record>s",
                                        policy_scoping_not_performed: "Policy scoping was not performed",
                                        authorization_not_performed: "Authorization was not performed"
                                      },
                                      policies: {
                                        post_policy: {
                                          update: {
                                            denied: "You cannot update this post",
                                            reason: "Only admins and post owners can update posts"
                                          },
                                          destroy: {
                                            denied: "You cannot delete this post"
                                          }
                                        }
                                      }
                                    })
  end

  def teardown
    SimpleAuthorize.reset_configuration!
  end

  # Configuration Tests

  test "i18n is disabled by default" do
    assert_equal false, SimpleAuthorize.configuration.i18n_enabled
  end

  test "i18n can be enabled via configuration" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    assert SimpleAuthorize.configuration.i18n_enabled
  end

  test "i18n scope defaults to simple_authorize" do
    assert_equal "simple_authorize", SimpleAuthorize.configuration.i18n_scope
  end

  test "i18n scope can be customized" do
    SimpleAuthorize.configure do |config|
      config.i18n_scope = "my_auth"
    end

    assert_equal "my_auth", SimpleAuthorize.configuration.i18n_scope
  end

  # NotAuthorizedError Message Tests

  test "error uses default message when i18n disabled" do
    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "update?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    assert_equal "not allowed to update? this Post", error.message
  end

  test "error uses i18n translation when enabled" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "update?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    assert_equal "You cannot update this post", error.message
  end

  test "error falls back to generic message when specific translation missing" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "publish?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    assert_equal "You are not authorized to perform this action", error.message
  end

  test "error supports interpolation with record type and action" do
    I18n.backend.store_translations(:en, simple_authorize: {
                                      policies: {
                                        post_policy: {
                                          create: {
                                            denied: "Cannot create %<record_type>s as %<user_role>s"
                                          }
                                        }
                                      }
                                    })

    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "create?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    assert_match(/Cannot create Post/, error.message)
  end

  # Controller Integration Tests

  test "controller uses i18n error message when authorization fails" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    controller = MockController.new(@viewer)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    assert_equal "You cannot update this post", error.message
  end

  test "controller uses default message when i18n disabled" do
    controller = MockController.new(@viewer)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    assert_equal "not allowed to update? this Post", error.message
  end

  # API Error Message Tests

  test "api errors use shorter i18n message when available" do
    I18n.backend.store_translations(:en, simple_authorize: {
                                      policies: {
                                        post_policy: {
                                          update: {
                                            api_denied: "Cannot update post"
                                          }
                                        }
                                      }
                                    })

    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "update?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    # API message should prefer api_denied if present
    assert_equal "You cannot update this post", error.message
  end

  # Policy Scoping Error Messages

  test "policy scoping error still works with i18n enabled" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    controller = MockController.new(@viewer)

    error = assert_raises(SimpleAuthorize::Controller::PolicyScopingNotPerformedError) do
      controller.verify_policy_scoped
    end

    # PolicyScopingNotPerformedError doesn't need I18n for now - it's a developer error, not user-facing
    assert_includes error.message, "MockController#update"
    assert_includes error.message, "missing policy scope"
  end

  # Translation Key Lookup Tests

  test "looks up translation in correct order" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    # Should check:
    # 1. simple_authorize.policies.post_policy.destroy.denied
    # 2. simple_authorize.errors.not_authorized
    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "destroy?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    assert_equal "You cannot delete this post", error.message
  end

  test "respects custom i18n scope" do
    I18n.backend.store_translations(:en, my_custom_auth: {
                                      errors: {
                                        not_authorized: "Custom unauthorized message"
                                      }
                                    })

    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
      config.i18n_scope = "my_custom_auth"
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "publish?",
      record: @post,
      policy: PostPolicy.new(@viewer, @post)
    )

    assert_equal "Custom unauthorized message", error.message
  end

  # Edge Cases

  test "handles nil user gracefully with i18n" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "update?",
      record: @post,
      policy: PostPolicy.new(nil, @post)
    )

    assert_equal "You cannot update this post", error.message
  end

  test "handles missing policy class in translation" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    # Create a policy class without translations
    custom_policy_class = Class.new(SimpleAuthorize::Policy) do
      def self.name
        "UnknownPolicy"
      end

      def update?
        false
      end
    end

    custom_policy = custom_policy_class.new(@viewer, @post)

    error = SimpleAuthorize::Controller::NotAuthorizedError.new(
      query: "update?",
      record: @post,
      policy: custom_policy
    )

    # Should fall back to default message since unknown_policy has no translations
    assert_equal "You are not authorized to perform this action", error.message
  end

  test "plain string errors still work with i18n enabled" do
    SimpleAuthorize.configure do |config|
      config.i18n_enabled = true
    end

    error = SimpleAuthorize::Controller::NotAuthorizedError.new("Custom error message")

    assert_equal "Custom error message", error.message
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
