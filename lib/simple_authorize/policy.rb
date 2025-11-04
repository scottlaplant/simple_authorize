# frozen_string_literal: true

module SimpleAuthorize
  # Base policy class that all other policies inherit from.
  #
  # Policies encapsulate authorization logic for a specific model or resource.
  # Each policy typically corresponds to a model class and defines methods
  # that determine whether a user can perform specific actions.
  #
  # @abstract Subclass and override query methods to implement authorization logic
  #
  # @example Basic policy implementation
  #   class PostPolicy < ApplicationPolicy
  #     def update?
  #       user.present? && (record.user_id == user.id || user.admin?)
  #     end
  #
  #     def destroy?
  #       update? # Same logic as update
  #     end
  #   end
  #
  # @example Using helper methods
  #   class PostPolicy < ApplicationPolicy
  #     def update?
  #       owner? || admin?
  #     end
  #   end
  #
  # @example With attribute-level authorization
  #   class PostPolicy < ApplicationPolicy
  #     def visible_attributes
  #       if admin?
  #         [:id, :title, :body, :user_id, :published]
  #       elsif owner?
  #         [:id, :title, :body, :published]
  #       else
  #         [:id, :title, :body]
  #       end
  #     end
  #   end
  #
  # @see SimpleAuthorize::Controller For controller integration
  class Policy
    # @return [Object] the user performing the action (typically User model instance or nil)
    attr_reader :user

    # @return [Object] the record being authorized (typically an ActiveRecord model instance)
    attr_reader :record

    # Initialize a new policy instance.
    #
    # @param user [Object] the user performing the action (can be nil for guest users)
    # @param record [Object] the record being authorized
    #
    # @example
    #   policy = PostPolicy.new(current_user, @post)
    #   policy.update? # => true or false
    def initialize(user, record)
      @user = user
      @record = record
    end

    # Default policies - deny everything by default for security

    # Determine if user can view a list/index of records.
    #
    # @return [Boolean] false by default (deny-all for security)
    #
    # @example Override in subclass
    #   def index?
    #     logged_in?
    #   end
    def index?
      false
    end

    # Determine if user can view a specific record.
    #
    # @return [Boolean] false by default (deny-all for security)
    #
    # @example Override in subclass
    #   def show?
    #     true # Public content
    #   end
    def show?
      false
    end

    # Determine if user can create a new record.
    #
    # @return [Boolean] false by default (deny-all for security)
    #
    # @example Override in subclass
    #   def create?
    #     logged_in?
    #   end
    def create?
      false
    end

    # Determine if user can access the new record form.
    # Delegates to {#create?} by default.
    #
    # @return [Boolean] result of {#create?}
    def new?
      create?
    end

    # Determine if user can update an existing record.
    #
    # @return [Boolean] false by default (deny-all for security)
    #
    # @example Override in subclass
    #   def update?
    #     owner? || admin?
    #   end
    def update?
      false
    end

    # Determine if user can access the edit record form.
    # Delegates to {#update?} by default.
    #
    # @return [Boolean] result of {#update?}
    def edit?
      update?
    end

    # Determine if user can destroy/delete a record.
    #
    # @return [Boolean] false by default (deny-all for security)
    #
    # @example Override in subclass
    #   def destroy?
    #     admin?
    #   end
    def destroy?
      false
    end

    # Attribute-level authorization

    # Returns array of attributes that the user can view.
    #
    # Override this method to define which attributes should be visible
    # to the current user. Supports action-specific variants like
    # `visible_attributes_for_index` and `visible_attributes_for_show`.
    #
    # @return [Array<Symbol>] empty array by default (no attributes visible)
    #
    # @example Basic implementation
    #   def visible_attributes
    #     if admin?
    #       [:id, :title, :body, :user_id]
    #     else
    #       [:id, :title, :body]
    #     end
    #   end
    #
    # @example Action-specific attributes
    #   def visible_attributes_for_index
    #     [:id, :title] # Brief for lists
    #   end
    #
    #   def visible_attributes_for_show
    #     [:id, :title, :body, :published] # Full for detail
    #   end
    def visible_attributes
      []
    end

    # Returns array of attributes that the user can edit/modify.
    #
    # Override this method to define which attributes can be modified
    # by the current user. Supports action-specific variants like
    # `editable_attributes_for_create` and `editable_attributes_for_update`.
    #
    # @return [Array<Symbol>] empty array by default (no attributes editable)
    #
    # @example Basic implementation
    #   def editable_attributes
    #     if admin?
    #       [:title, :body, :published]
    #     elsif owner?
    #       [:title, :body]
    #     else
    #       []
    #     end
    #   end
    #
    # @example Action-specific attributes
    #   def editable_attributes_for_create
    #     [:title, :body] # Can't set published on create
    #   end
    #
    #   def editable_attributes_for_update
    #     admin? ? [:title, :body, :published] : [:title, :body]
    #   end
    def editable_attributes
      []
    end

    # Check if a specific attribute is visible to the user.
    #
    # @param attribute [String, Symbol] the attribute name to check
    # @return [Boolean] true if attribute is in {#visible_attributes}
    #
    # @example
    #   policy.attribute_visible?(:email) # => true or false
    def attribute_visible?(attribute)
      visible_attributes.include?(attribute.to_sym)
    end

    # Check if a specific attribute is editable by the user.
    #
    # @param attribute [String, Symbol] the attribute name to check
    # @return [Boolean] true if attribute is in {#editable_attributes}
    #
    # @example
    #   policy.attribute_editable?(:published) # => true or false
    def attribute_editable?(attribute)
      editable_attributes.include?(attribute.to_sym)
    end

    # @!group Helper Methods
    #
    # Protected helper methods available in all policies to reduce boilerplate.
    # These methods make policy code more readable and maintainable.

    protected

    # Check if the current user has admin role.
    #
    # @return [Boolean] true if user has admin role
    # @note Requires user object to respond to `admin?` method
    #
    # @example
    #   def destroy?
    #     admin? # Only admins can destroy
    #   end
    def admin?
      user&.admin?
    end

    # Check if the current user has contributor role.
    #
    # @return [Boolean] true if user has contributor role
    # @note Requires user object to respond to `contributor?` method
    def contributor?
      user&.contributor?
    end

    # Check if the current user has viewer role.
    #
    # @return [Boolean] true if user has viewer role
    # @note Requires user object to respond to `viewer?` method
    def viewer?
      user&.viewer?
    end

    # Check if the current user owns the record.
    #
    # @return [Boolean] true if record's user_id matches current user's id
    # @note Requires record to respond to `user_id` method
    #
    # @example
    #   def update?
    #     owner? || admin?
    #   end
    def owner?
      record.respond_to?(:user_id) && record.user_id == user&.id
    end

    # Check if there is a current user (not a guest).
    #
    # @return [Boolean] true if user is present
    #
    # @example
    #   def create?
    #     logged_in? # Must be authenticated to create
    #   end
    def logged_in?
      user.present?
    end

    # Check if the current user can create content.
    #
    # @return [Boolean] true if user can create content
    # @note Requires user object to respond to `can_create_content?` method
    def can_create_content?
      user&.can_create_content?
    end

    # Check if the current user can manage content.
    #
    # @return [Boolean] true if user can manage content
    # @note Requires user object to respond to `can_manage_content?` method
    def can_manage_content?
      user&.can_manage_content?
    end

    # @!endgroup

    # Scope class for filtering collections based on user permissions.
    #
    # Used to filter ActiveRecord relations to show only records that
    # the user is authorized to see. Each policy should define its own
    # Scope class to customize collection filtering logic.
    #
    # @example Basic scope implementation
    #   class PostPolicy < ApplicationPolicy
    #     class Scope < ApplicationPolicy::Scope
    #       def resolve
    #         if user&.admin?
    #           scope.all
    #         else
    #           scope.where(published: true)
    #         end
    #       end
    #     end
    #   end
    #
    # @example In controller
    #   def index
    #     @posts = policy_scope(Post)
    #   end
    #
    # @see SimpleAuthorize::Controller#policy_scope
    class Scope
      # @return [Object] the user performing the action
      attr_reader :user

      # @return [ActiveRecord::Relation] the relation to be filtered
      attr_reader :scope

      # Initialize a new scope instance.
      #
      # @param user [Object] the user requesting the collection
      # @param scope [ActiveRecord::Relation] the base relation to filter
      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      # Resolve the scope to return filtered results.
      #
      # Override this method in subclasses to implement custom filtering.
      # By default returns all records (no filtering).
      #
      # @return [ActiveRecord::Relation] filtered relation
      #
      # @example Override in subclass
      #   def resolve
      #     if user&.admin?
      #       scope.all
      #     else
      #       scope.where(published: true)
      #     end
      #   end
      def resolve
        scope.all
      end

      protected

      # Check if the current user has admin role.
      #
      # @return [Boolean] true if user has admin role
      def admin?
        user&.admin?
      end
    end
  end
end
