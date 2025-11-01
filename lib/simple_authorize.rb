# frozen_string_literal: true

require "active_support/all"
require_relative "simple_authorize/version"
require_relative "simple_authorize/configuration"
require_relative "simple_authorize/controller"
require_relative "simple_authorize/policy"

module SimpleAuthorize
  class Error < StandardError; end
end

# Only load Railtie if Rails is defined
if defined?(Rails::Railtie)
  require_relative "simple_authorize/railtie"
end
