# frozen_string_literal: true

module SimpleAuthorize
  # Base policy class that all other policies inherit from
  class Policy
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
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

    # Helper methods
    protected

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

      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        scope.all
      end

      protected

      def admin?
        user&.admin?
      end
    end
  end
end
