# frozen_string_literal: true

module SimpleAuthorize
  # Test helpers for Minitest
  # Include this module in your test cases to get assertion methods for authorization testing
  #
  # @example
  #   class PostPolicyTest < ActiveSupport::TestCase
  #     include SimpleAuthorize::TestHelpers
  #
  #     def test_admin_can_destroy
  #       policy = PostPolicy.new(admin_user, post)
  #       assert_permit_action(policy, :destroy)
  #     end
  #   end
  module TestHelpers
    # Assert that a policy permits a specific action
    #
    # @param policy [SimpleAuthorize::Policy] The policy instance to test
    # @param action [Symbol, String] The action to check (e.g., :show, :update)
    # @param message [String] Optional custom failure message
    #
    # @example
    #   assert_permit_action(policy, :show)
    #   assert_permit_action(policy, "update")
    def assert_permit_action(policy, action, message = nil)
      action_method = action.to_s.end_with?("?") ? action.to_s : "#{action}?"
      result = policy.public_send(action_method)

      message ||= "Expected #{policy.class} to permit action :#{action} but it was forbidden"
      assert result, message
    end

    # Assert that a policy forbids a specific action
    #
    # @param policy [SimpleAuthorize::Policy] The policy instance to test
    # @param action [Symbol, String] The action to check (e.g., :destroy, :update)
    # @param message [String] Optional custom failure message
    #
    # @example
    #   assert_forbid_action(policy, :destroy)
    #   assert_forbid_action(policy, "update")
    def assert_forbid_action(policy, action, message = nil)
      action_method = action.to_s.end_with?("?") ? action.to_s : "#{action}?"
      result = policy.public_send(action_method)

      message ||= "Expected #{policy.class} to forbid action :#{action} but it was permitted"
      assert_not result, message
    end

    # Assert that a policy permits viewing a specific attribute
    #
    # @param policy [SimpleAuthorize::Policy] The policy instance to test
    # @param attribute [Symbol, String] The attribute to check (e.g., :title, :email)
    # @param message [String] Optional custom failure message
    #
    # @example
    #   assert_permit_viewing(policy, :title)
    #   assert_permit_viewing(policy, "email")
    def assert_permit_viewing(policy, attribute, message = nil)
      result = policy.attribute_visible?(attribute)

      message ||= "Expected #{policy.class} to permit viewing :#{attribute} but it was hidden"
      assert result, message
    end

    # Assert that a policy forbids viewing a specific attribute
    #
    # @param policy [SimpleAuthorize::Policy] The policy instance to test
    # @param attribute [Symbol, String] The attribute to check (e.g., :password, :secret)
    # @param message [String] Optional custom failure message
    #
    # @example
    #   assert_forbid_viewing(policy, :user_id)
    #   assert_forbid_viewing(policy, "password")
    def assert_forbid_viewing(policy, attribute, message = nil)
      result = policy.attribute_visible?(attribute)

      message ||= "Expected #{policy.class} to forbid viewing :#{attribute} but it was visible"
      assert_not result, message
    end

    # Assert that a policy permits editing a specific attribute
    #
    # @param policy [SimpleAuthorize::Policy] The policy instance to test
    # @param attribute [Symbol, String] The attribute to check (e.g., :title, :body)
    # @param message [String] Optional custom failure message
    #
    # @example
    #   assert_permit_editing(policy, :title)
    #   assert_permit_editing(policy, "body")
    def assert_permit_editing(policy, attribute, message = nil)
      result = policy.attribute_editable?(attribute)

      message ||= "Expected #{policy.class} to permit editing :#{attribute} but it was not editable"
      assert result, message
    end

    # Assert that a policy forbids editing a specific attribute
    #
    # @param policy [SimpleAuthorize::Policy] The policy instance to test
    # @param attribute [Symbol, String] The attribute to check (e.g., :id, :created_at)
    # @param message [String] Optional custom failure message
    #
    # @example
    #   assert_forbid_editing(policy, :published)
    #   assert_forbid_editing(policy, "id")
    def assert_forbid_editing(policy, attribute, message = nil)
      result = policy.attribute_editable?(attribute)

      message ||= "Expected #{policy.class} to forbid editing :#{attribute} but it was editable"
      assert_not result, message
    end
  end
end
