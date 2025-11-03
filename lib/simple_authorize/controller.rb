# frozen_string_literal: true

module SimpleAuthorize
  # Enhanced authorization system with full feature parity
  # Provides comprehensive authorization without external dependencies
  module Controller
    extend ActiveSupport::Concern

    # Custom error classes for authorization
    class NotAuthorizedError < StandardError
      attr_reader :query, :record, :policy

      def initialize(options = {})
        if options.is_a?(String)
          # Handle plain string message
          super
        else
          # Handle hash options
          @query = options[:query]
          @record = options[:record]
          @policy = options[:policy]

          message = options[:message] || "not allowed to #{@query} this #{@record.class}"
          super(message)
        end
      end
    end

    class PolicyNotDefinedError < StandardError; end
    class AuthorizationNotPerformedError < StandardError; end
    class PolicyScopingNotPerformedError < StandardError; end
    # Alias for backwards compatibility
    ScopingNotPerformedError = PolicyScopingNotPerformedError

    included do
      # Make these available as helper methods in views
      helper_method :policy, :policy_scope, :authorized_user if respond_to?(:helper_method)
    end

    # Module to enable automatic verification - opt-in for safety
    module AutoVerify
      extend ActiveSupport::Concern

      included do
        # Track whether authorization was performed
        after_action :verify_authorized, except: :index
        after_action :verify_policy_scoped, only: :index
      end
    end

    # Core authorization methods

    def authorize(record, query = nil, policy_class: nil)
      query ||= "#{action_name}?"
      @_policy = policy(record, policy_class: policy_class)

      authorized = @_policy.public_send(query)
      error = nil

      error = NotAuthorizedError.new(query: query, record: record, policy: @_policy) unless authorized

      # Emit instrumentation event
      instrument_authorization(record, query, @_policy.class, authorized, error) if instrumentation_enabled?

      raise error if error

      @authorization_performed = true
      record
    end

    # Authorize and raise exception if not authorized
    def authorize!(record, query = nil, policy_class: nil)
      authorize(record, query, policy_class: policy_class)
    end

    # Get or instantiate policy for a record
    def policy(record, policy_class: nil, namespace: nil)
      policy_class ||= if namespace
                         policy_class_for(record, namespace: namespace)
                       else
                         policy_class_for(record)
                       end

      # Return cached policy if caching is enabled
      if SimpleAuthorize.configuration.enable_policy_cache
        policy_cache_key = build_policy_cache_key(record, policy_class)
        @_policy_cache ||= {}
        @_policy_cache[policy_cache_key] ||= policy_class.new(authorized_user, record)
      else
        policy_class.new(authorized_user, record)
      end
    rescue NameError
      raise PolicyNotDefinedError, "unable to find policy `#{policy_class}` for `#{record}`"
    end

    # Ensure policy exists, raising if not found
    def policy!(record, policy_class: nil)
      policy(record, policy_class: policy_class)
    end

    # Scope a relation using the policy scope
    def policy_scope(scope, policy_scope_class: nil)
      @policy_scoping_performed = true

      policy_scope_class ||= policy_scope_class_for(scope)
      result = nil
      error = nil

      begin
        result = policy_scope_class.new(authorized_user, scope).resolve
      rescue NameError
        error = PolicyNotDefinedError.new("unable to find scope `#{policy_scope_class}` for `#{scope}`")
      end

      # Emit instrumentation event
      instrument_policy_scope(scope, policy_scope_class, error) if instrumentation_enabled?

      raise error if error

      result
    end

    # Ensure scope exists, raising if not found
    def policy_scope!(scope, policy_scope_class: nil)
      policy_scope(scope, policy_scope_class: policy_scope_class)
    end

    # Get permitted attributes for strong parameters
    def permitted_attributes(record, action = nil)
      action ||= action_name
      policy = policy(record)
      method_name = "permitted_attributes_for_#{action}"

      if policy.respond_to?(method_name)
        policy.public_send(method_name)
      elsif policy.respond_to?(:permitted_attributes)
        policy.permitted_attributes
      else
        raise PolicyNotDefinedError, "unable to find permitted attributes for #{record}"
      end
    end

    # Automatically build permitted params from policy
    def policy_params(record, param_key = nil)
      param_key ||= record.model_name.param_key
      params.require(param_key).permit(*permitted_attributes(record))
    end

    # Verify that authorization was performed
    def verify_authorized
      return if authorization_performed?

      raise AuthorizationNotPerformedError, "#{self.class}##{action_name} is missing authorization"
    end

    # Verify that scoping was performed for index actions
    def verify_policy_scoped
      return if policy_scoped?

      raise PolicyScopingNotPerformedError, "#{self.class}##{action_name} is missing policy scope"
    end

    # Skip authorization verification for specific actions
    def skip_authorization
      @authorization_performed = true
    end

    # Skip policy scope verification for specific actions
    def skip_policy_scope
      @policy_scoping_performed = true
    end

    # Check if authorization was performed
    def authorization_performed?
      @authorization_performed == true
    end

    # Check if policy scoping was performed
    def policy_scoped?
      @policy_scoping_performed == true
    end

    # Get the user for authorization (can be overridden)
    def authorized_user
      current_user
    end

    # Clear the policy cache
    def clear_policy_cache
      @_policy_cache = nil
    end

    # Reset authorization tracking (useful in tests)
    def reset_authorization
      @authorization_performed = nil
      @policy_scoping_performed = nil
      @_policy = nil
      clear_policy_cache
    end

    # Support for headless policies (policies without a model)
    def authorize_headless(policy_class, query = nil)
      query ||= "#{action_name}?"
      policy = policy_class.new(authorized_user, nil)

      authorized = policy.public_send(query)
      error = nil

      error = NotAuthorizedError.new(query: query, record: policy_class, policy: policy) unless authorized

      # Emit instrumentation event (with nil record for headless policies)
      instrument_authorization(nil, query, policy_class, authorized, error) if instrumentation_enabled?

      raise error if error

      @authorization_performed = true
      true
    end

    # Check if user can perform action without raising
    def allowed_to?(action, record, policy_class: nil)
      policy = policy(record, policy_class: policy_class)
      policy.public_send("#{action}?")
    rescue PolicyNotDefinedError
      false
    end

    # Get all allowed actions for a record
    def allowed_actions(record)
      policy = policy(record)
      actions = []

      %i[index? show? create? update? destroy?].each do |method|
        actions << method.to_s.delete("?").to_sym if policy.respond_to?(method) && policy.public_send(method)
      end

      actions
    end

    # Role helper methods
    def admin_user?
      current_user&.admin?
    end

    def contributor_user?
      current_user&.contributor?
    end

    def viewer_user?
      current_user&.viewer?
    end

    # Alias for handle_unauthorized that matches common convention
    def user_not_authorized(exception = nil)
      handle_unauthorized(exception)
    end

    protected

    # Build a cache key for a policy instance
    # The key is based on user, record, and policy class to ensure proper scoping
    def build_policy_cache_key(record, policy_class)
      user_key = authorized_user&.id || authorized_user.object_id
      record_key = if record.respond_to?(:id) && record.id.present?
                     "#{record.class.name}-#{record.id}"
                   else
                     "#{record.class.name}-#{record.object_id}"
                   end
      policy_key = policy_class.name

      "#{user_key}/#{record_key}/#{policy_key}"
    end

    # Check if instrumentation is enabled
    def instrumentation_enabled?
      SimpleAuthorize.configuration.enable_instrumentation
    end

    # Emit authorization instrumentation event
    def instrument_authorization(record, query, policy_class, authorized, error)
      ActiveSupport::Notifications.instrument("authorize.simple_authorize",
                                              build_instrumentation_payload(record, query, policy_class, authorized,
                                                                            error))
    end

    # Emit policy scope instrumentation event
    def instrument_policy_scope(scope, policy_scope_class, error)
      ActiveSupport::Notifications.instrument("policy_scope.simple_authorize",
                                              build_scope_payload(scope, policy_scope_class, error))
    end

    # Build payload for authorization events
    def build_instrumentation_payload(record, query, policy_class, authorized, error)
      payload = {
        user: authorized_user,
        user_id: authorized_user&.id,
        record: record,
        record_id: record.respond_to?(:id) ? record&.id : nil,
        record_class: record&.class&.name,
        query: query.to_s,
        policy_class: policy_class,
        authorized: authorized,
        error: error
      }

      # Add controller and action info if available
      payload[:controller] = controller_name if respond_to?(:controller_name)
      payload[:action] = action_name if respond_to?(:action_name)

      payload
    end

    # Build payload for policy scope events
    def build_scope_payload(scope, policy_scope_class, error)
      payload = {
        user: authorized_user,
        user_id: authorized_user&.id,
        scope: scope,
        policy_scope_class: policy_scope_class,
        error: error
      }

      # Add controller and action info if available
      payload[:controller] = controller_name if respond_to?(:controller_name)
      payload[:action] = action_name if respond_to?(:action_name)

      payload
    end

    def policy_class_for(record, namespace: nil)
      klass = record.class
      record_class = if record.is_a?(Class)
                       record.name
                     elsif record.respond_to?(:model_name)
                       record.model_name.to_s
                     elsif klass.respond_to?(:model_name)
                       klass.model_name.to_s
                     else
                       klass.name
                     end

      policy_class_name = if namespace
                            "#{namespace.to_s.camelize}::#{record_class}Policy"
                          else
                            "#{record_class}Policy"
                          end

      begin
        policy_class_name.constantize
      rescue NameError
        # Fall back to non-namespaced policy if namespaced one doesn't exist
        raise unless namespace

        "#{record_class}Policy".constantize
      end
    end

    def policy_scope_class_for(scope)
      if scope.respond_to?(:model_name)
        "#{scope.model_name}Policy::Scope".constantize
      elsif scope.is_a?(Class)
        "#{scope}Policy::Scope".constantize
      else
        "#{scope.class}Policy::Scope".constantize
      end
    end

    # Handle authorization errors
    def handle_unauthorized(exception = nil)
      flash[:alert] = "You are not authorized to perform this action."
      safe_redirect_path = safe_referrer_path || root_path

      if exception
        redirect_to(safe_redirect_path, status: :see_other)
      else
        redirect_to(safe_redirect_path)
      end
    end

    # Safely get referrer path, only if it's from our own domain
    def safe_referrer_path
      referrer = request.referrer
      return nil unless referrer.present?

      referrer_uri = URI.parse(referrer)
      request_uri = URI.parse(request.url)

      # Only allow referrers from the same host
      referrer_uri.path if referrer_uri.host == request_uri.host
    rescue URI::InvalidURIError
      nil
    end

    # Class methods for controller configuration
    class_methods do
      # Rescue from authorization errors
      def rescue_from_authorization_errors
        rescue_from SimpleAuthorize::Controller::NotAuthorizedError, with: :handle_unauthorized
      end

      # Skip authorization for specific actions
      def skip_authorization_check(*actions)
        skip_after_action :verify_authorized, only: actions
        skip_after_action :verify_policy_scoped, only: actions
      end

      # Skip all authorization checks for controller
      def skip_all_authorization_checks
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped
      end

      # Configure which actions need authorization
      def authorize_actions(*actions)
        after_action :verify_authorized, only: actions
      end

      # Configure which actions need policy scoping
      def scope_actions(*actions)
        after_action :verify_policy_scoped, only: actions
      end
    end
  end
end
