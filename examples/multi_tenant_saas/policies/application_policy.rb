# Base policy for multi-tenant SaaS with tenant isolation
class ApplicationPolicy < SimpleAuthorize::Policy
  class Scope < SimpleAuthorize::Policy::Scope
    def resolve
      if super_admin?
        scope.all  # Super admins can see all tenants
      elsif user&.tenant_id
        scope.where(tenant_id: user.tenant_id)  # Automatic tenant isolation
      else
        scope.none  # No tenant = no access
      end
    end

    protected

    def super_admin?
      user&.super_admin?
    end
  end

  protected

  # Check if user is a super admin with cross-tenant access
  def super_admin?
    user&.super_admin?
  end

  # Check if record belongs to user's tenant
  def same_tenant?
    return false unless user&.tenant_id
    record.respond_to?(:tenant_id) && record.tenant_id == user.tenant_id
  end

  # Tenant role checks
  def tenant_owner?
    user&.role_in_tenant(current_tenant) == "owner"
  end

  def tenant_admin?
    %w[owner admin].include?(user&.role_in_tenant(current_tenant))
  end

  def team_member?
    %w[owner admin member].include?(user&.role_in_tenant(current_tenant))
  end

  def viewer?
    user&.role_in_tenant(current_tenant) == "viewer"
  end

  def current_tenant
    record.respond_to?(:tenant) ? record.tenant : user&.tenant
  end
end
