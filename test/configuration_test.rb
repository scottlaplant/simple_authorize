# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  def setup
    # Reset configuration before each test
    SimpleAuthorize.reset_configuration!
  end

  def teardown
    # Reset configuration after each test
    SimpleAuthorize.reset_configuration!
  end

  test "has default configuration values" do
    config = SimpleAuthorize.configuration

    assert_equal "You are not authorized to perform this action.", config.default_error_message
    assert_equal false, config.auto_verify
    assert_equal :current_user, config.current_user_method
    assert_nil config.unauthorized_redirect_path
  end

  test "can configure default_error_message" do
    SimpleAuthorize.configure do |config|
      config.default_error_message = "Access denied!"
    end

    assert_equal "Access denied!", SimpleAuthorize.configuration.default_error_message
  end

  test "can configure auto_verify" do
    SimpleAuthorize.configure do |config|
      config.auto_verify = true
    end

    assert SimpleAuthorize.configuration.auto_verify
  end

  test "can configure current_user_method" do
    SimpleAuthorize.configure do |config|
      config.current_user_method = :authenticated_user
    end

    assert_equal :authenticated_user, SimpleAuthorize.configuration.current_user_method
  end

  test "can configure unauthorized_redirect_path" do
    SimpleAuthorize.configure do |config|
      config.unauthorized_redirect_path = "/unauthorized"
    end

    assert_equal "/unauthorized", SimpleAuthorize.configuration.unauthorized_redirect_path
  end

  test "can configure multiple settings at once" do
    SimpleAuthorize.configure do |config|
      config.default_error_message = "Custom error"
      config.auto_verify = true
      config.current_user_method = :user
      config.unauthorized_redirect_path = "/forbidden"
    end

    config = SimpleAuthorize.configuration
    assert_equal "Custom error", config.default_error_message
    assert config.auto_verify
    assert_equal :user, config.current_user_method
    assert_equal "/forbidden", config.unauthorized_redirect_path
  end

  test "reset_configuration! restores defaults" do
    SimpleAuthorize.configure do |config|
      config.default_error_message = "Custom"
      config.auto_verify = true
    end

    SimpleAuthorize.reset_configuration!

    config = SimpleAuthorize.configuration
    assert_equal "You are not authorized to perform this action.", config.default_error_message
    assert_equal false, config.auto_verify
  end

  test "configuration is accessible via module method" do
    assert_instance_of SimpleAuthorize::Configuration, SimpleAuthorize.configuration
  end
end
