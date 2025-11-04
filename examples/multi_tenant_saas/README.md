# Multi-Tenant SaaS Application Example

This example demonstrates a multi-tenant SaaS application with SimpleAuthorize, showcasing:

- Tenant isolation (users can only access their own tenant's data)
- User roles within tenants: Owner, Admin, Member, Viewer
- Cross-tenant admin (super admin)
- Subscription-based feature access
- Team member management

## Models

- **Tenant**: Represents an organization/company (has subscription tier)
- **User**: Belongs to a Tenant, has role within tenant
- **Project**: Belongs to Tenant
- **Document**: Belongs to Project (and therefore Tenant)
- **TeamMember**: Join model for User + Tenant with role

## User Roles

### Super Admin
- Can access all tenants
- Can manage tenant subscriptions
- Full system access

### Tenant Owner
- Full access within their tenant
- Can manage billing and subscription
- Can add/remove team members
- Can assign roles

### Tenant Admin
- Full access to tenant data
- Can add/remove team members (except owner)
- Cannot manage billing

### Team Member
- Can create and manage their own projects
- Can collaborate on shared projects
- Limited access based on project permissions

### Viewer
- Read-only access to tenant data
- Cannot create or modify resources

## Multi-Tenancy Pattern

### Tenant Scoping
All policies automatically scope to the current tenant:

```ruby
class ApplicationPolicy < SimpleAuthorize::Policy
  protected

  def tenant_match?
    return true if super_admin?
    record.tenant_id == user&.tenant_id
  end

  def same_tenant?
    tenant_match?
  end
end
```

### Automatic Tenant Filtering
```ruby
class ProjectPolicy::Scope
  def resolve
    if super_admin?
      scope.all  # Super admins see all tenants
    else
      scope.where(tenant_id: user&.tenant_id)  # Automatic tenant isolation
    end
  end
end
```

## Authorization Rules

### Projects (within tenant)

| Action  | Viewer | Member | Admin | Owner | Super Admin |
|---------|--------|--------|-------|-------|-------------|
| index   | ✓      | ✓      | ✓     | ✓     | ✓           |
| show    | ✓      | ✓      | ✓     | ✓     | ✓           |
| create  | ✗      | ✓      | ✓     | ✓     | ✓           |
| update  | ✗      | ✓ (own)| ✓     | ✓     | ✓           |
| destroy | ✗      | ✓ (own)| ✓     | ✓     | ✓           |

### Team Members

| Action  | Viewer | Member | Admin | Owner | Super Admin |
|---------|--------|--------|-------|-------|-------------|
| index   | ✓      | ✓      | ✓     | ✓     | ✓           |
| invite  | ✗      | ✗      | ✓     | ✓     | ✓           |
| remove  | ✗      | ✗      | ✓     | ✓     | ✓           |
| change_role | ✗  | ✗      | ✓ (not owner) | ✓ | ✓       |

### Tenant Settings

| Action  | Viewer | Member | Admin | Owner | Super Admin |
|---------|--------|--------|-------|-------|-------------|
| view    | ✗      | ✗      | ✓     | ✓     | ✓           |
| update  | ✗      | ✗      | ✗     | ✓     | ✓           |
| billing | ✗      | ✗      | ✗     | ✓     | ✓           |

## Key Features

### Tenant Isolation

```ruby
# Automatic tenant filtering in controllers
class ProjectsController < ApplicationController
  def index
    # policy_scope automatically filters to current tenant
    @projects = policy_scope(Project)
  end

  def show
    @project = Project.find(params[:id])
    authorize @project  # Verifies project belongs to user's tenant
  end
end
```

### Role-Based Permissions

```ruby
class ProjectPolicy < ApplicationPolicy
  def update?
    return true if super_admin?
    return false unless same_tenant?

    tenant_owner? || tenant_admin? || (team_member? && owner?)
  end

  protected

  def tenant_owner?
    user&.role_in_tenant(record.tenant) == "owner"
  end

  def tenant_admin?
    user&.role_in_tenant(record.tenant) == "admin"
  end
end
```

### Subscription-Based Features

```ruby
class DocumentPolicy < ApplicationPolicy
  def create?
    return false unless logged_in? && same_tenant?
    return true if super_admin?

    # Check if tenant's subscription allows this feature
    tenant = record.tenant || user.tenant
    return false unless tenant.subscription_active?

    # Check if within plan limits
    if tenant.plan == "free" && tenant.documents.count >= 10
      return false
    end

    team_member? || tenant_admin? || tenant_owner?
  end
end
```

## Usage Example

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include SimpleAuthorize::Controller

  before_action :set_current_tenant

  private

  def set_current_tenant
    Current.tenant = current_user&.tenant
  end
end

# app/policies/project_policy.rb
class ProjectPolicy < ApplicationPolicy
  def show?
    return true if super_admin?
    same_tenant? && (viewer? || higher_role?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if super_admin?
        scope.all
      else
        scope.where(tenant_id: user&.tenant_id)
      end
    end
  end

  protected

  def same_tenant?
    record.tenant_id == user&.tenant_id
  end

  def higher_role?
    team_member? || tenant_admin? || tenant_owner?
  end
end
```

## Testing

```ruby
test "users cannot access projects from other tenants" do
  user_tenant_a = User.new(id: 1, tenant_id: 1, role: "admin")
  project_tenant_b = Project.new(id: 1, tenant_id: 2)

  policy = ProjectPolicy.new(user_tenant_a, project_tenant_b)
  assert_forbid_action policy, :show
end

test "super admins can access all tenants" do
  super_admin = User.new(id: 1, tenant_id: nil, super_admin: true)
  project_any_tenant = Project.new(id: 1, tenant_id: 999)

  policy = ProjectPolicy.new(super_admin, project_any_tenant)
  assert_permit_action policy, :show
end

test "tenant owners can manage team members" do
  owner = User.new(id: 1, tenant_id: 1, role: "owner")
  team_member = TeamMember.new(tenant_id: 1)

  policy = TeamMemberPolicy.new(owner, team_member)
  assert_permit_action policy, :destroy
end
```

## Key Takeaways

1. **Tenant Isolation**: Automatic filtering ensures users never see other tenants' data
2. **Hierarchical Roles**: Owner > Admin > Member > Viewer within each tenant
3. **Super Admin**: Cross-tenant access for system administrators
4. **Subscription Awareness**: Authorization checks subscription plan and limits
5. **Team Management**: Fine-grained control over who can manage team members
6. **Secure by Default**: All policies check tenant ownership before role-based rules

## Configuration

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  config.current_user_method = :current_user
  config.enable_policy_cache = true  # Important for multi-tenant performance
  config.enable_instrumentation = true  # Track cross-tenant access attempts
end

# Subscribe to authorization events for security monitoring
ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, id, payload|
  if payload[:record]&.respond_to?(:tenant_id)
    # Log if user tried to access different tenant
    if payload[:user]&.tenant_id != payload[:record].tenant_id
      SecurityLogger.warn("Cross-tenant access attempt", payload)
    end
  end
end
```
