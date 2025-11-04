# frozen_string_literal: true

module SimpleAuthorize
  # Controller integration for SimpleAuthorize authorization system.
  #
  # Include this module in your ApplicationController to add authorization
  # capabilities to your Rails application. Provides methods for authorizing
  # actions, filtering scopes, managing attributes, and handling errors.
  #
  # @example Basic setup
  #   class ApplicationController < ActionController::Base
  #     include SimpleAuthorize::Controller
  #     rescue_from_authorization_errors
  #   end
  #
  # @example In a controller action
  #   def update
  #     @post = Post.find(params[:id])
  #     authorize @post
  #     if @post.update(policy_params(@post))
  #       redirect_to @post
  #     else
  #       render :edit
  #     end
  #   end
  #
  # @example With scoping
  #   def index
  #     @posts = policy_scope(Post)
  #   end
  #
  # @see SimpleAuthorize::Policy For policy implementation
  module Controller
    extend ActiveSupport::Concern

    # Exception raised when a user is not authorized to perform an action.
    #
    # This error includes information about the query method, record, and policy
    # that was used. It supports I18n for custom error messages.
    #
    # @example Rescuing authorization errors
    #   rescue_from SimpleAuthorize::Controller::NotAuthorizedError, with: :user_not_authorized
    #
    #   def user_not_authorized(exception)
    #     flash[:alert] = exception.message
    #     redirect_to root_path
    #   end
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

    # Exception raised when a policy class cannot be found for a record.
    #
    # @example
    #   authorize @post  # raises if PostPolicy doesn't exist
    class PolicyNotDefinedError < StandardError; end

    # Exception raised when an action completes without calling {#authorize}.
    #
    # Only raised when using {AutoVerify} module or calling {#verify_authorized}.
    #
    # @see AutoVerify
    # @see #verify_authorized
    class AuthorizationNotPerformedError < StandardError; end

    # Exception raised when an index action completes without calling {#policy_scope}.
    #
    # Only raised when using {AutoVerify} module or calling {#verify_policy_scoped}.
    #
    # @see AutoVerify
    # @see #verify_policy_scoped
    class PolicyScopingNotPerformedError < StandardError; end

    # Alias for backwards compatibility
    ScopingNotPerformedError = PolicyScopingNotPerformedError

    included do
      # Make these available as helper methods in views
      helper_method :policy, :policy_scope, :authorized_user if respond_to?(:helper_method)
    end

    # Automatic verification module to ensure all actions are authorized.
    #
    # Include this module to automatically verify that every controller action
    # calls either {#authorize} or {#policy_scope}. Helps prevent accidentally
    # forgetting to authorize actions.
    #
    # @example Enable auto-verification
    #   class ApplicationController < ActionController::Base
    #     include SimpleAuthorize::Controller
    #     include SimpleAuthorize::Controller::AutoVerify
    #   end
    #
    # @example Skip verification for specific actions
    #   class PostsController < ApplicationController
    #     skip_authorization_check only: [:public_index]
    #   end
    module AutoVerify
      extend ActiveSupport::Concern

      included do
        # Track whether authorization was performed
        after_action :verify_authorized, except: :index
        after_action :verify_policy_scoped, only: :index
      end
    end

    # @!group Core Authorization Methods

    # Authorize an action on a record.
    #
    # Checks if the current user is authorized to perform the specified action
    # on the given record. Raises {NotAuthorizedError} if not authorized.
    #
    # @param record [Object] the record to authorize (e.g., Post, Comment)
    # @param query [String, Symbol, nil] the policy method to call (e.g., :update?, :destroy?)
    #   Defaults to "#{action_name}?" if not provided
    # @param policy_class [Class, nil] optional policy class to use instead of auto-detected
    #
    # @return [Object] the record that was authorized
    #
    # @raise [NotAuthorizedError] if user is not authorized
    # @raise [PolicyNotDefinedError] if policy class cannot be found
    #
    # @example Basic usage
    #   def update
    #     @post = Post.find(params[:id])
    #     authorize @post  # Calls PostPolicy.new(current_user, @post).update?
    #     @post.update(post_params)
    #   end
    #
    # @example With explicit query
    #   def publish
    #     @post = Post.find(params[:id])
    #     authorize @post, :publish?  # Calls PostPolicy#publish?
    #   end
    #
    # @example With custom policy class
    #   def update
    #     @post = Post.find(params[:id])
    #     authorize @post, policy_class: AdminPostPolicy
    #   end
    #
    # @see #authorize!
    # @see #policy
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

    # Alias for {#authorize} - explicitly raises exception if not authorized.
    #
    # Behaves identically to {#authorize}, always raising an exception if
    # authorization fails. Provided for API clarity.
    #
    # @param (see #authorize)
    # @return (see #authorize)
    # @raise (see #authorize)
    #
    # @see #authorize
    def authorize!(record, query = nil, policy_class: nil)
      authorize(record, query, policy_class: policy_class)
    end

    # Get or instantiate a policy for a record.
    #
    # Returns the policy instance for the given record. Policies are cached
    # per-request if {Configuration#enable_policy_cache} is enabled.
    # Available as a helper method in views.
    #
    # @param record [Object] the record to get a policy for
    # @param policy_class [Class, nil] optional policy class to use
    # @param namespace [Symbol, nil] optional namespace for namespaced policies
    #
    # @return [SimpleAuthorize::Policy] the policy instance
    #
    # @raise [PolicyNotDefinedError] if policy class cannot be found
    #
    # @example In controller
    #   @post = Post.find(params[:id])
    #   policy(@post).update?  # => true or false
    #
    # @example In view
    #   <% if policy(@post).update? %>
    #     <%= link_to "Edit", edit_post_path(@post) %>
    #   <% end %>
    #
    # @example With custom policy class
    #   policy(@post, policy_class: AdminPostPolicy)
    #
    # @see #authorize
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

    # Alias for {#policy} - explicitly raises if policy not found.
    #
    # @param (see #policy)
    # @return (see #policy)
    # @raise (see #policy)
    #
    # @see #policy
    def policy!(record, policy_class: nil)
      policy(record, policy_class: policy_class)
    end

    # Filter a collection/scope based on user permissions.
    #
    # Uses the policy's Scope class to filter an ActiveRecord relation,
    # returning only records that the user is permitted to see.
    # Available as a helper method in views.
    #
    # @param scope [ActiveRecord::Relation, Class] the relation or model class to filter
    # @param policy_scope_class [Class, nil] optional scope class to use
    #
    # @return [ActiveRecord::Relation] filtered relation
    #
    # @raise [PolicyNotDefinedError] if scope class cannot be found
    #
    # @example Basic usage
    #   def index
    #     @posts = policy_scope(Post)  # Uses PostPolicy::Scope
    #   end
    #
    # @example With ActiveRecord relation
    #   def index
    #     @posts = policy_scope(Post.published)  # Filters published posts
    #   end
    #
    # @example In view
    #   <% policy_scope(Post).each do |post| %>
    #     <%= post.title %>
    #   <% end %>
    #
    # @see SimpleAuthorize::Policy::Scope
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

    # Alias for {#policy_scope} - explicitly raises if scope not found.
    #
    # @param (see #policy_scope)
    # @return (see #policy_scope)
    # @raise (see #policy_scope)
    #
    # @see #policy_scope
    def policy_scope!(scope, policy_scope_class: nil)
      policy_scope(scope, policy_scope_class: policy_scope_class)
    end

    # @!endgroup

    # @!group Strong Parameters Integration

    # Get permitted attributes from policy for strong parameters.
    #
    # Returns an array of attribute names that the user is allowed to modify
    # for the given record and action. Looks for action-specific methods first
    # (e.g., `permitted_attributes_for_create`), falling back to general
    # `permitted_attributes` method.
    #
    # @param record [Object] the record being modified
    # @param action [String, Symbol, nil] the action name (defaults to current action)
    #
    # @return [Array<Symbol>] array of permitted attribute names
    #
    # @raise [PolicyNotDefinedError] if policy doesn't define permitted attributes
    #
    # @example Basic usage
    #   def create
    #     @post = Post.new
    #     attrs = permitted_attributes(@post)  # [:title, :body]
    #     @post.assign_attributes(params[:post].permit(*attrs))
    #   end
    #
    # @example Action-specific
    #   # Looks for PostPolicy#permitted_attributes_for_create
    #   permitted_attributes(@post, :create)  # => [:title, :body]
    #
    #   # Looks for PostPolicy#permitted_attributes_for_update
    #   permitted_attributes(@post, :update)  # => [:title, :body, :published]
    #
    # @see #policy_params
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

    # Get attributes that the user can view for a record.
    #
    # Returns an array of attribute names that should be visible to the user.
    # Looks for action-specific methods first (e.g., `visible_attributes_for_show`),
    # falling back to general `visible_attributes` method.
    #
    # @param record [Object] the record being viewed
    # @param action [String, Symbol, nil] the action name (defaults to current action)
    #
    # @return [Array<Symbol>] array of visible attribute names
    #
    # @example Basic usage
    #   def show
    #     @post = Post.find(params[:id])
    #     @visible_attrs = visible_attributes(@post)
    #   end
    #
    # @example In view
    #   <% visible_attributes(@post).each do |attr| %>
    #     <p><strong><%= attr %>:</strong> <%= @post.send(attr) %></p>
    #   <% end %>
    #
    # @see #editable_attributes
    # @see #filter_attributes
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

    # Get attributes that the user can edit for a record.
    #
    # Returns an array of attribute names that should be editable by the user.
    # Looks for action-specific methods first (e.g., `editable_attributes_for_update`),
    # falling back to general `editable_attributes` method.
    #
    # @param record [Object] the record being edited
    # @param action [String, Symbol, nil] the action name (defaults to current action)
    #
    # @return [Array<Symbol>] array of editable attribute names
    #
    # @example Basic usage
    #   def edit
    #     @post = Post.find(params[:id])
    #     @editable_attrs = editable_attributes(@post)
    #   end
    #
    # @see #visible_attributes
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

    # Filter a hash of attributes to only include visible ones.
    #
    # Takes a hash of attributes and returns a new hash containing only
    # attributes that are in the {#visible_attributes} list for the record.
    #
    # @param record [Object] the record to check visibility against
    # @param attributes [Hash] hash of attribute key-value pairs
    #
    # @return [Hash] filtered hash with only visible attributes
    #
    # @example
    #   attrs = { id: 1, title: "Post", secret_key: "abc123" }
    #   filter_attributes(@post, attrs)  # => { id: 1, title: "Post" }
    #
    # @see #visible_attributes
    def filter_attributes(record, attributes)
      visible = visible_attributes(record)
      attributes.select { |key, _value| visible.include?(key.to_sym) }
    end

    # Automatically build permitted params from policy.
    #
    # Convenience method that combines `params.require().permit()` with
    # policy-defined permitted attributes. Simplifies strong parameters setup.
    #
    # @param record [Object] the record being created/updated
    # @param param_key [String, Symbol, nil] the params key (defaults to model's param_key)
    #
    # @return [ActionController::Parameters] permitted parameters
    #
    # @example Basic usage
    #   def create
    #     @post = Post.new(policy_params(Post.new))
    #     @post.save
    #   end
    #
    # @example With custom param key
    #   def create
    #     @post = Post.new(policy_params(Post.new, :custom_post))
    #   end
    #
    # @example Instead of manual permit
    #   # Instead of:
    #   params.require(:post).permit(*permitted_attributes(@post))
    #
    #   # Use:
    #   policy_params(@post)
    #
    # @see #permitted_attributes
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
