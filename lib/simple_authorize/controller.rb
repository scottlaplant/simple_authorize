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

          message = options[:message] || build_error_message
          super(message)
        end
      end

      private

      def build_error_message
        # Return default message if I18n is disabled
        return "not allowed to #{@query} this #{@record.class}" unless i18n_enabled?

        # Try to find translation with fallback chain
        translate_error || default_i18n_message
      end

      def i18n_enabled?
        SimpleAuthorize.configuration.i18n_enabled
      end

      def translate_error
        return nil unless defined?(I18n)
        return nil unless @policy&.class

        # Extract action name from query (remove trailing ?)
        action = @query.to_s.delete_suffix("?")
        policy_class_name = @policy.class.name
        return nil unless policy_class_name

        policy_name = policy_class_name.underscore

        # Try specific policy + action translation
        key = "#{i18n_scope}.policies.#{policy_name}.#{action}.denied"
        translation = I18n.t(key, **translation_options, default: nil)
        return translation if translation.present?

        nil
      rescue StandardError
        # If any error occurs during translation lookup, return nil to use default
        nil
      end

      def translation_options
        {
          record_type: @record&.class&.name || "record",
          record_id: @record.respond_to?(:id) ? @record.id : nil,
          action: @query.to_s.delete_suffix("?"),
          user_role: @policy&.user&.role || "user"
        }.compact
      end

      def default_i18n_message
        return "not allowed to #{@query} this #{@record.class}" unless defined?(I18n)

        I18n.t("#{i18n_scope}.errors.not_authorized",
               default: "You are not authorized to perform this action")
      end

      def i18n_scope
        SimpleAuthorize.configuration.i18n_scope
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
        @_policy_cache[policy_cache_key] ||= policy_class.new(authorized_user, record, context: authorization_context)
      else
        policy_class.new(authorized_user, record, context: authorization_context)
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
        result = policy_scope_class.new(authorized_user, scope, context: authorization_context).resolve
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

    # Get visible attributes for a record
    def visible_attributes(record, action = nil)
      action ||= action_name
      policy = policy(record)
      method_name = "visible_attributes_for_#{action}"

      if policy.respond_to?(method_name)
        policy.public_send(method_name)
      elsif policy.respond_to?(:visible_attributes)
        policy.visible_attributes
      else
        []
      end
    end

    # Get editable attributes for a record
    def editable_attributes(record, action = nil)
      action ||= action_name
      policy = policy(record)
      method_name = "editable_attributes_for_#{action}"

      if policy.respond_to?(method_name)
        policy.public_send(method_name)
      elsif policy.respond_to?(:editable_attributes)
        policy.editable_attributes
      else
        []
      end
    end

    # Filter a hash of attributes to only include visible ones
    def filter_attributes(record, attributes)
      visible = visible_attributes(record)
      attributes.select { |key, _value| visible.include?(key.to_sym) }
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

    # Build context for authorization (can be overridden)
    # Override this method in your ApplicationController to provide
    # context data for policies
    #
    # Example:
    #   def authorization_context
    #     {
    #       ip_address: request.remote_ip,
    #       user_agent: request.user_agent,
    #       subdomain: request.subdomain,
    #       current_time: Time.current,
    #       request_count: rate_limiter.count_for(current_user),
    #       two_factor_verified: session[:two_factor_verified],
    #       user_plan: current_user&.subscription&.plan
    #     }
    #   end
    def authorization_context
      {}
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
      query = action.to_s.end_with?("?") ? action.to_s : "#{action}?"
      policy.public_send(query)
    rescue PolicyNotDefinedError
      false
    end

    # Batch Authorization Methods

    # Authorize all records or raise on first failure
    def authorize_all(records, query = nil, policy_class: nil)
      query ||= "#{action_name}?"

      records.each do |record|
        authorize(record, query, policy_class: policy_class)
      end

      records
    end

    # Return only authorized records
    def authorized_records(records, query = nil, policy_class: nil)
      query ||= "#{action_name}?"

      records.select do |record|
        allowed_to?(query, record, policy_class: policy_class)
      end
    end

    # Partition records into [authorized, unauthorized]
    def partition_records(records, query = nil, policy_class: nil)
      query ||= "#{action_name}?"

      records.partition do |record|
        allowed_to?(query, record, policy_class: policy_class)
      end
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

    # Check if current request is an API request (JSON/XML)
    def api_request?
      return false unless respond_to?(:request)

      # Check request format
      return true if request.respond_to?(:format) && (request.format.json? || request.format.xml?)

      # Check Accept header
      if request.respond_to?(:headers) && request.headers["Accept"]
        accept = request.headers["Accept"].to_s
        return true if accept.include?("application/json") || accept.include?("application/xml")
      end

      # Check Content-Type header
      if request.respond_to?(:headers) && request.headers["Content-Type"]
        content_type = request.headers["Content-Type"].to_s
        return true if content_type.include?("application/json") || content_type.include?("application/xml")
      end

      false
    end

    # Handle API authorization errors with JSON response
    def handle_api_authorization_error(exception)
      status = exception.record.nil? || authorized_user.nil? ? 401 : 403
      message = SimpleAuthorize.configuration.default_error_message

      body = {
        error: "not_authorized",
        message: message
      }

      # Add detailed information if configured
      if SimpleAuthorize.configuration.api_error_details
        body[:query] = exception.query.to_s
        body[:record_type] = exception.record&.class&.name
        body[:policy] = exception.policy&.class&.name
      end

      {
        status: status,
        content_type: "application/json",
        body: body
      }
    end

    # Build an API error response
    def api_error_response(message:, status: 403, details: nil)
      body = {
        error: "not_authorized",
        message: message
      }

      body[:details] = details if details

      {
        status: status,
        content_type: "application/json",
        body: body
      }
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
      # Handle API requests with JSON response
      if api_request? && exception.is_a?(NotAuthorizedError)
        response = handle_api_authorization_error(exception)
        render json: response[:body], status: response[:status]
        return
      end

      # Handle traditional HTML requests with redirect
      flash[:alert] = SimpleAuthorize.configuration.default_error_message
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
