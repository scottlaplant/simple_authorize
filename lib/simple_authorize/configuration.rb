# frozen_string_literal: true

module SimpleAuthorize
  # Configuration options for SimpleAuthorize.
  #
  # Configure SimpleAuthorize in an initializer file to customize behavior
  # across your application.
  #
  # @example Basic configuration
  #   # config/initializers/simple_authorize.rb
  #   SimpleAuthorize.configure do |config|
  #     config.default_error_message = "Access denied!"
  #     config.enable_policy_cache = true
  #     config.enable_instrumentation = true
  #   end
  #
  # @example With I18n
  #   SimpleAuthorize.configure do |config|
  #     config.i18n_enabled = true
  #     config.i18n_scope = "authorization"
  #   end
  #
  # @see SimpleAuthorize.configure
  class Configuration
    # Default error message shown to users when not authorized.
    #
    # @return [String] the default error message
    # @example
    #   config.default_error_message = "Sorry, you don't have permission."
    attr_accessor :default_error_message

    # Whether to enable automatic verification of authorization calls.
    #
    # When true, automatically verifies that every controller action
    # calls {Controller#authorize} or {Controller#policy_scope}.
    #
    # @return [Boolean] whether auto-verification is enabled
    # @note This is opt-in and defaults to false. Use {Controller::AutoVerify} instead for more control.
    # @example
    #   config.auto_verify = true
    attr_accessor :auto_verify

    # The method name to call to get the current user.
    #
    # @return [Symbol] method name that returns the current user
    # @example With Devise
    #   config.current_user_method = :current_user
    #
    # @example With custom auth
    #   config.current_user_method = :authenticated_user
    attr_accessor :current_user_method

    # Custom redirect path for unauthorized access in web requests.
    #
    # @return [String, nil] path to redirect to (nil uses root_path or referrer)
    # @example
    #   config.unauthorized_redirect_path = "/access_denied"
    attr_accessor :unauthorized_redirect_path

    # Enable request-level policy instance caching for performance.
    #
    # When enabled, policy instances are cached per-request and reused
    # for the same user + record + policy class combination.
    #
    # @return [Boolean] whether policy caching is enabled
    # @note Improves performance in views with multiple authorization checks
    # @example
    #   config.enable_policy_cache = true
    attr_accessor :enable_policy_cache

    # Enable ActiveSupport::Notifications instrumentation for authorization events.
    #
    # When enabled, emits `authorize.simple_authorize` and `policy_scope.simple_authorize`
    # events that can be subscribed to for logging, monitoring, or auditing.
    #
    # @return [Boolean] whether instrumentation is enabled (default: true)
    # @example
    #   config.enable_instrumentation = true
    #
    # @example Subscribe to events
    #   ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, id, payload|
    #     Rails.logger.info("Authorization: #{payload[:authorized]}")
    #   end
    attr_accessor :enable_instrumentation

    # Include detailed error information in API error responses.
    #
    # When enabled, API responses include additional context like
    # query method, record type, and user information.
    #
    # @return [Boolean] whether to include detailed API errors (default: false)
    # @note Only affects JSON/XML API responses, not HTML
    # @example
    #   config.api_error_details = true
    attr_accessor :api_error_details

    # Enable I18n (internationalization) support for error messages.
    #
    # When enabled, looks up error messages in translation files
    # with fallback to default messages.
    #
    # @return [Boolean] whether I18n is enabled (default: false)
    # @example
    #   config.i18n_enabled = true
    #
    # @example Translation file structure
    #   # config/locales/simple_authorize.en.yml
    #   en:
    #     simple_authorize:
    #       policies:
    #         post_policy:
    #           update:
    #             denied: "You cannot edit this post"
    attr_accessor :i18n_enabled

    # I18n scope for translation lookups.
    #
    # @return [String] the I18n scope (default: "simple_authorize")
    # @example
    #   config.i18n_scope = "authorization"
    attr_accessor :i18n_scope

    # Initialize configuration with default values.
    #
    # @api private
    def initialize
      @default_error_message = "You are not authorized to perform this action."
      @auto_verify = false
      @current_user_method = :current_user
      @unauthorized_redirect_path = nil
      @enable_policy_cache = false
      @enable_instrumentation = true
      @api_error_details = false
      @i18n_enabled = false
      @i18n_scope = "simple_authorize"
    end
  end

  class << self
    # @!attribute [w] configuration
    #   @return [Configuration] the configuration instance
    #   @api private
    attr_writer :configuration

    # Get the current configuration instance.
    #
    # @return [Configuration] the current configuration
    #
    # @example
    #   SimpleAuthorize.configuration.enable_policy_cache  # => false
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure SimpleAuthorize with a block.
    #
    # Yields the configuration object for modification. This is the
    # primary way to configure SimpleAuthorize.
    #
    # @yield [Configuration] the configuration object
    # @return [void]
    #
    # @example
    #   SimpleAuthorize.configure do |config|
    #     config.default_error_message = "Access denied!"
    #     config.enable_policy_cache = true
    #   end
    #
    # @see Configuration
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults.
    #
    # Primarily used in testing to ensure a clean slate between tests.
    #
    # @return [Configuration] the new configuration instance
    #
    # @example In test teardown
    #   def teardown
    #     SimpleAuthorize.reset_configuration!
    #   end
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
