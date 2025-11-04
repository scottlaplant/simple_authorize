# Policy for Project with tenant isolation and role-based access
class ProjectPolicy < ApplicationPolicy
  def index?
    logged_in?
  end

  def show?
    return true if super_admin?
    same_tenant? && (viewer? || team_member? || tenant_admin?)
  end

  def create?
    return true if super_admin?
    same_tenant? && (team_member? || tenant_admin?)
  end

  def update?
    return true if super_admin?
    return false unless same_tenant?

    tenant_admin? || (team_member? && owner?)
  end

  def destroy?
    return true if super_admin?
    return false unless same_tenant?

    tenant_owner? || tenant_admin? || (team_member? && owner?)
  end

  def permitted_attributes
    if super_admin? || tenant_admin?
      [:name, :description, :status, :user_id]
    elsif team_member?
      [:name, :description, :status]
    else
      []
    end
  end

  def visible_attributes
    if super_admin? || tenant_admin?
      [:id, :name, :description, :status, :user_id, :tenant_id, :created_at, :updated_at]
    elsif team_member? || viewer?
      [:id, :name, :description, :status, :created_at]
    else
      []
    end
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if super_admin?
        scope.all
      elsif user&.tenant_id
        scope.where(tenant_id: user.tenant_id)
      else
        scope.none
      end
    end
  end
end
