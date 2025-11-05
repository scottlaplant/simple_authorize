# frozen_string_literal: true

require "active_support/all"
require_relative "simple_authorize/version"
require_relative "simple_authorize/configuration"
require_relative "simple_authorize/controller"
require_relative "simple_authorize/policy"
require_relative "simple_authorize/policy_modules"
require_relative "simple_authorize/test_helpers"

# SimpleAuthorize provides a lightweight authorization framework for Rails applications
# without external dependencies. It offers policy-based access control inspired by Pundit.
module SimpleAuthorize
  class Error < StandardError; end
end

# Only load Railtie if Rails is defined
require_relative "simple_authorize/railtie" if defined?(Rails::Railtie)
