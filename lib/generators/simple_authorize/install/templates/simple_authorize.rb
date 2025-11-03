# frozen_string_literal: true

# Configure SimpleAuthorize
SimpleAuthorize.configure do |config|
  # Default error message shown to users when not authorized
  # config.default_error_message = "You are not authorized to perform this action."

  # Enable automatic verification (requires including SimpleAuthorize::Controller::AutoVerify)
  # config.auto_verify = false

  # The method to call to get the current user (default: current_user)
  # config.current_user_method = :current_user

  # Custom redirect path for unauthorized access (default: uses referrer or root_path)
  # config.unauthorized_redirect_path = "/unauthorized"

  # Enable policy caching for performance optimization (default: false)
  # When enabled, policy instances are cached per request, scoped by user, record, and policy class
  # config.enable_policy_cache = true
end
