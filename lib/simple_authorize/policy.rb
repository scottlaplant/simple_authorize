# frozen_string_literal: true

module SimpleAuthorize
  # Base policy class that all other policies inherit from
  class Policy
    attr_reader :user, :record

    def initialize(user, record, context: nil)
      @user = user
      @record = record
      @context = context
    end

    # Default policies - deny everything by default
    def index?
      false
    end

    def show?
      false
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      false
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    # Attribute-level authorization

    # Returns array of attributes visible to the user
    def visible_attributes
      []
    end

    # Returns array of attributes editable by the user
    def editable_attributes
      []
    end

    # Check if a specific attribute is visible
    def attribute_visible?(attribute)
      visible_attributes.include?(attribute.to_sym)
    end

    # Check if a specific attribute is editable
    def attribute_editable?(attribute)
      editable_attributes.include?(attribute.to_sym)
    end

    # Helper methods
    protected

    def context
      @context || {}
    end

    def admin?
      user&.admin?
    end

    def contributor?
      user&.contributor?
    end

    def viewer?
      user&.viewer?
    end

    def owner?
      record.respond_to?(:user_id) && record.user_id == user&.id
    end

    def logged_in?
      user.present?
    end

    def can_create_content?
      user&.can_create_content?
    end

    def can_manage_content?
      user&.can_manage_content?
    end

    # Scope class for filtering collections
    class Scope
      attr_reader :user, :scope

      def initialize(user, scope, context: nil)
        @user = user
        @scope = scope
        @context = context
      end

      def resolve
        scope.all
      end

      protected

      def context
        @context || {}
      end

      def admin?
        user&.admin?
      end
    end
  end
end
