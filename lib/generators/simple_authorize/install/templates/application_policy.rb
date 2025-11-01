# frozen_string_literal: true

# Base policy class that all other policies inherit from
# Inherits from SimpleAuthorize::Policy which provides default deny-all policies
class ApplicationPolicy < SimpleAuthorize::Policy
  # Override default policies here if needed
  # For example, allow all logged-in users to view index:
  # def index?
  #   logged_in?
  # end

  # Add custom helper methods here
  # protected
  #
  # def owned_by_user?
  #   record.user_id == user&.id
  # end

  # Scope class for filtering collections
  class Scope < SimpleAuthorize::Policy::Scope
    # Override the resolve method to customize collection filtering
    # def resolve
    #   if admin?
    #     scope.all
    #   else
    #     scope.where(published: true)
    #   end
    # end
  end
end
