# frozen_string_literal: true

module SimpleAuthorize
  # Configuration options for SimpleAuthorize
  class Configuration
    # Default error message shown to users when not authorized
    attr_accessor :default_error_message

    # Whether to enable automatic verification (opt-in)
    attr_accessor :auto_verify

    # The method to call to get the current user (default: current_user)
    attr_accessor :current_user_method

    # Custom redirect path for unauthorized access
    attr_accessor :unauthorized_redirect_path

    # Enable policy caching for performance optimization (opt-in)
    attr_accessor :enable_policy_cache

    def initialize
      @default_error_message = "You are not authorized to perform this action."
      @auto_verify = false
      @current_user_method = :current_user
      @unauthorized_redirect_path = nil
      @enable_policy_cache = false
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
