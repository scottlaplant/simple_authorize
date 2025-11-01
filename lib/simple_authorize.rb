# frozen_string_literal: true

require "active_support/all"
require_relative "simple_authorize/version"
require_relative "simple_authorize/configuration"
require_relative "simple_authorize/controller"
require_relative "simple_authorize/policy"

module SimpleAuthorize
  class Error < StandardError; end

  # Railtie for automatic integration with Rails
  class Railtie < Rails::Railtie
    initializer "simple_authorize.configure" do
      ActiveSupport.on_load(:action_controller) do
        # Make SimpleAuthorize::Controller available as Authorization for backwards compatibility
        ::Authorization = SimpleAuthorize::Controller unless defined?(::Authorization)
        # Make SimpleAuthorize::Policy available as ApplicationPolicy for backwards compatibility
        ::ApplicationPolicy = SimpleAuthorize::Policy unless defined?(::ApplicationPolicy)
      end
    end

    # Generate initializer template
    generators do
      require_relative "generators/simple_authorize/install/install_generator"
    end
  end
end
