# Base application policy that all other policies inherit from
class ApplicationPolicy < SimpleAuthorize::Policy
  # Default: deny all actions for security
  # Subclasses should override specific actions to allow access

  class Scope < SimpleAuthorize::Policy::Scope
    # Default: return all records
    # Subclasses should override to filter based on permissions
    def resolve
      scope.all
    end
  end
end
