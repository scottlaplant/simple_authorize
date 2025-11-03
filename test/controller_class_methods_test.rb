# frozen_string_literal: true

require "test_helper"

# Tests for controller class methods
class ControllerClassMethodsTest < ActiveSupport::TestCase
  def setup
    @admin = User.new(id: 1, role: :admin)
    @viewer = User.new(id: 3, role: :viewer)
    @post = Post.new(id: 1, user_id: 2)
  end

  # rescue_from_authorization_errors Tests

  test "rescue_from_authorization_errors sets up rescue_from" do
    controller_class = Class.new do
      include SimpleAuthorize::Controller

      def self.rescue_from(error_class, options = {})
        @rescued_from = [error_class, options]
      end

      class << self
        attr_reader :rescued_from
      end

      rescue_from_authorization_errors
    end

    rescued = controller_class.rescued_from
    assert_equal SimpleAuthorize::Controller::NotAuthorizedError, rescued[0]
    assert_equal :handle_unauthorized, rescued[1][:with]
  end

  # skip_authorization_check Tests

  test "skip_authorization_check skips verification for specified actions" do
    controller_class = Class.new do
      include SimpleAuthorize::Controller

      def self.skip_after_action(callback, options = {})
        @skipped_actions ||= []
        @skipped_actions << { callback: callback, only: options[:only] }
      end

      def self.skipped_actions
        @skipped_actions || []
      end

      skip_authorization_check :show, :index
    end

    skipped = controller_class.skipped_actions

    verify_skipped = skipped.find { |s| s[:callback] == :verify_authorized }
    scope_skipped = skipped.find { |s| s[:callback] == :verify_policy_scoped }

    assert_equal %i[show index], verify_skipped[:only]
    assert_equal %i[show index], scope_skipped[:only]
  end

  # skip_all_authorization_checks Tests

  test "skip_all_authorization_checks skips all verification" do
    controller_class = Class.new do
      include SimpleAuthorize::Controller

      def self.skip_after_action(callback, _options = {})
        @skipped_all ||= []
        @skipped_all << callback
      end

      def self.skipped_all
        @skipped_all || []
      end

      skip_all_authorization_checks
    end

    skipped = controller_class.skipped_all

    assert_includes skipped, :verify_authorized
    assert_includes skipped, :verify_policy_scoped
  end

  # authorize_actions Tests

  test "authorize_actions adds verification for specified actions" do
    controller_class = Class.new do
      include SimpleAuthorize::Controller

      def self.after_action(callback, options = {})
        @authorized_actions ||= []
        @authorized_actions << { callback: callback, only: options[:only] }
      end

      def self.authorized_actions
        @authorized_actions || []
      end

      authorize_actions :create, :update, :destroy
    end

    actions = controller_class.authorized_actions
    verify_action = actions.find { |a| a[:callback] == :verify_authorized }

    assert_equal %i[create update destroy], verify_action[:only]
  end

  # scope_actions Tests

  test "scope_actions adds scope verification for specified actions" do
    controller_class = Class.new do
      include SimpleAuthorize::Controller

      def self.after_action(callback, options = {})
        @scoped_actions ||= []
        @scoped_actions << { callback: callback, only: options[:only] }
      end

      def self.scoped_actions
        @scoped_actions || []
      end

      scope_actions :index, :search
    end

    actions = controller_class.scoped_actions
    scope_action = actions.find { |a| a[:callback] == :verify_policy_scoped }

    assert_equal %i[index search], scope_action[:only]
  end

  # AutoVerify Module Tests

  test "AutoVerify adds after_action callbacks" do
    controller_class = Class.new do
      include SimpleAuthorize::Controller

      def self.after_action(callback, options = {})
        @callbacks ||= []
        @callbacks << { callback: callback, except: options[:except], only: options[:only] }
      end

      def self.callbacks
        @callbacks || []
      end

      include SimpleAuthorize::Controller::AutoVerify
    end

    callbacks = controller_class.callbacks

    verify_callback = callbacks.find { |c| c[:callback] == :verify_authorized }
    scope_callback = callbacks.find { |c| c[:callback] == :verify_policy_scoped }

    assert_equal :index, verify_callback[:except]
    assert_equal :index, scope_callback[:only]
  end
end
