# frozen_string_literal: true

require "test_helper"

class TestSimpleAuthorize < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::SimpleAuthorize::VERSION
  end

  def test_module_exists
    assert defined?(SimpleAuthorize)
  end

  def test_controller_module_exists
    assert defined?(SimpleAuthorize::Controller)
  end

  def test_policy_class_exists
    assert defined?(SimpleAuthorize::Policy)
  end

  def test_configuration_class_exists
    assert defined?(SimpleAuthorize::Configuration)
  end

  def test_error_classes_exist
    assert defined?(SimpleAuthorize::Controller::NotAuthorizedError)
    assert defined?(SimpleAuthorize::Controller::PolicyNotDefinedError)
    assert defined?(SimpleAuthorize::Controller::AuthorizationNotPerformedError)
    assert defined?(SimpleAuthorize::Controller::PolicyScopingNotPerformedError)
  end
end
