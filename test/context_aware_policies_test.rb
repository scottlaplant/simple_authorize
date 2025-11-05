# frozen_string_literal: true

require "test_helper"

class ContextAwarePoliciesTest < ActiveSupport::TestCase
  # Test policy that uses context for authorization decisions
  class ContextAwarePostPolicy < SimpleAuthorize::Policy
    def index?
      true
    end

    def show?
      # Public posts are always visible
      return true if record.published

      # Unpublished posts require authentication
      return false unless logged_in?

      # Check IP-based access for unpublished content
      return true if context[:ip_address] && trusted_ip?(context[:ip_address])

      # Owner or admin can always see
      owner? || admin?
    end

    def create?
      return false unless logged_in?

      # Check rate limiting
      return false if context[:request_count] && (context[:request_count] > 100)

      # Check time-based restrictions
      return false if context[:current_time] && !business_hours?(context[:current_time])

      contributor? || admin?
    end

    def update?
      return false unless logged_in?

      # Geographic restrictions
      return false if context[:country] && restricted_country?(context[:country])

      # 2FA requirement for sensitive operations
      return owner? || admin? if context[:two_factor_verified]

      # Without 2FA, only admins can update
      admin?
    end

    def destroy?
      return false unless admin?

      # Additional security context check
      return context[:security_level] == "high" if context[:security_level]

      true
    end

    def export?
      return false unless logged_in?

      # Check export permissions based on plan
      if context[:user_plan]
        case context[:user_plan]
        when "enterprise"
          true
        when "pro"
          owner? || admin?
        when "basic"
          admin?
        else
          false
        end
      else
        admin?
      end
    end

    private

    def trusted_ip?(ip)
      trusted_ips = ["192.168.1.1", "10.0.0.1"]
      trusted_ips.include?(ip)
    end

    def business_hours?(time)
      hour = time.hour
      hour >= 9 && hour < 17 # 9 AM to 5 PM
    end

    def restricted_country?(country)
      restricted = ["Restrictedland"]
      restricted.include?(country)
    end

    def context
      @context || {}
    end
  end

  # Policy for testing context with scopes
  class ContextAwareDocumentPolicy < SimpleAuthorize::Policy
    def show?
      if context[:department]
        record.department == context[:department] || admin?
      else
        admin?
      end
    end

    class Scope < SimpleAuthorize::Policy::Scope
      def resolve
        if context[:department]
          if user&.admin?
            scope.all
          else
            scope.where({ department: context[:department] })
          end
        else
          user&.admin? ? scope.all : scope.none
        end
      end

      private

      def context
        @context || {}
      end
    end

    private

    def context
      @context || {}
    end
  end

  # Policy testing context inheritance in modules
  module GeographicallyRestricted
    def geographically_allowed?
      return true unless context[:country]

      allowed_countries = %w[USA Canada UK]
      allowed_countries.include?(context[:country])
    end

    def show?
      return false unless geographically_allowed?

      super
    end

    def update?
      return false unless geographically_allowed?

      super
    end

    private

    def context
      @context || {}
    end
  end

  class RestrictedContentPolicy < SimpleAuthorize::Policy
    def show?
      logged_in?
    end

    def update?
      owner? || admin?
    end

    prepend GeographicallyRestricted # Prepend to ensure module methods are called first

    private

    def context
      @context || {}
    end
  end

  def setup
    @admin = User.new(id: 1, role: :admin)
    @contributor = User.new(id: 2, role: :contributor)
    @viewer = User.new(id: 3, role: :viewer)

    @published_post = OpenStruct.new(
      id: 1,
      user_id: 2,
      published: true
    )

    @unpublished_post = OpenStruct.new(
      id: 2,
      user_id: 2,
      published: false
    )

    @document = OpenStruct.new(
      id: 1,
      department: "Engineering"
    )

    @content = OpenStruct.new(
      id: 1,
      user_id: 2
    )
  end

  # Basic context passing tests
  test "policy receives and uses context for authorization decisions" do
    # Without context, unpublished post is not visible to viewer
    policy = ContextAwarePostPolicy.new(@viewer, @unpublished_post)
    refute policy.show?, "Viewer cannot see unpublished post without context"

    # With trusted IP context, viewer can see unpublished post
    policy = ContextAwarePostPolicy.new(@viewer, @unpublished_post, context: { ip_address: "192.168.1.1" })
    assert policy.show?, "Viewer can see unpublished post from trusted IP"

    # With untrusted IP, still cannot see
    policy = ContextAwarePostPolicy.new(@viewer, @unpublished_post, context: { ip_address: "1.2.3.4" })
    refute policy.show?, "Viewer cannot see unpublished post from untrusted IP"
  end

  test "context affects create permissions based on rate limiting" do
    # Normal request count allows creation
    policy = ContextAwarePostPolicy.new(@contributor, @published_post, context: { request_count: 10 })
    assert policy.create?, "Contributor can create with low request count"

    # High request count blocks creation
    policy = ContextAwarePostPolicy.new(@contributor, @published_post, context: { request_count: 101 })
    refute policy.create?, "Contributor cannot create with high request count"

    # Admin is still affected by rate limiting
    policy = ContextAwarePostPolicy.new(@admin, @published_post, context: { request_count: 101 })
    refute policy.create?, "Even admin cannot create with high request count"
  end

  test "context enables time-based restrictions" do
    # During business hours
    business_time = Time.new(2024, 1, 1, 10, 0, 0) # 10 AM
    policy = ContextAwarePostPolicy.new(@contributor, @published_post, context: { current_time: business_time })
    assert policy.create?, "Contributor can create during business hours"

    # Outside business hours
    after_hours = Time.new(2024, 1, 1, 20, 0, 0) # 8 PM
    policy = ContextAwarePostPolicy.new(@contributor, @published_post, context: { current_time: after_hours })
    refute policy.create?, "Contributor cannot create outside business hours"
  end

  test "context enables geographic restrictions" do
    # Allowed country
    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: { country: "USA" })
    refute policy.update?, "Contributor cannot update even from allowed country without 2FA"

    # Restricted country
    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: { country: "Restrictedland" })
    refute policy.update?, "Cannot update from restricted country"

    # Admin from restricted country
    policy = ContextAwarePostPolicy.new(@admin, @unpublished_post, context: { country: "Restrictedland" })
    refute policy.update?, "Even admin cannot update from restricted country"
  end

  test "context enables 2FA requirements" do
    # Owner without 2FA cannot update
    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: { two_factor_verified: false })
    refute policy.update?, "Owner cannot update without 2FA"

    # Owner with 2FA can update
    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: { two_factor_verified: true })
    assert policy.update?, "Owner can update with 2FA"

    # Admin can update without 2FA
    policy = ContextAwarePostPolicy.new(@admin, @unpublished_post, context: { two_factor_verified: false })
    assert policy.update?, "Admin can update without 2FA"
  end

  test "context enables security level checks" do
    # Admin with high security can destroy
    policy = ContextAwarePostPolicy.new(@admin, @published_post, context: { security_level: "high" })
    assert policy.destroy?, "Admin can destroy with high security level"

    # Admin with low security cannot destroy
    policy = ContextAwarePostPolicy.new(@admin, @published_post, context: { security_level: "low" })
    refute policy.destroy?, "Admin cannot destroy with low security level"
  end

  test "context enables plan-based authorization" do
    # Enterprise plan can export
    policy = ContextAwarePostPolicy.new(@viewer, @published_post, context: { user_plan: "enterprise" })
    assert policy.export?, "Enterprise users can export"

    # Pro plan owner can export
    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: { user_plan: "pro" })
    assert policy.export?, "Pro plan owners can export their content"

    # Pro plan non-owner cannot export
    policy = ContextAwarePostPolicy.new(@viewer, @published_post, context: { user_plan: "pro" })
    refute policy.export?, "Pro plan non-owners cannot export"

    # Basic plan only admin can export
    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: { user_plan: "basic" })
    refute policy.export?, "Basic plan users cannot export"

    policy = ContextAwarePostPolicy.new(@admin, @published_post, context: { user_plan: "basic" })
    assert policy.export?, "Basic plan admin can export"
  end

  test "context works with policy scopes" do
    # Create a mock scope
    mock_scope = Minitest::Mock.new

    # Test with department context
    mock_scope.expect :where, "filtered_records", [{ department: "Engineering" }]
    scope = ContextAwareDocumentPolicy::Scope.new(@viewer, mock_scope, context: { department: "Engineering" })
    assert_equal "filtered_records", scope.resolve
    mock_scope.verify

    # Test without department context (non-admin)
    mock_scope2 = Minitest::Mock.new
    mock_scope2.expect :none, "no_records", []
    scope = ContextAwareDocumentPolicy::Scope.new(@viewer, mock_scope2)
    assert_equal "no_records", scope.resolve
    mock_scope2.verify

    # Test admin with department context
    mock_scope3 = Minitest::Mock.new
    mock_scope3.expect :all, "all_records", []
    scope = ContextAwareDocumentPolicy::Scope.new(@admin, mock_scope3, context: { department: "Engineering" })
    assert_equal "all_records", scope.resolve
    mock_scope3.verify
  end

  test "context works with composed policy modules" do
    # Test without geographic context
    policy = RestrictedContentPolicy.new(@contributor, @content)
    assert policy.show?, "Can view without geographic context"
    assert policy.update?, "Owner can update without geographic context"

    # Test with allowed country
    policy = RestrictedContentPolicy.new(@contributor, @content, context: { country: "USA" })
    assert policy.show?, "Can view from allowed country"
    assert policy.update?, "Owner can update from allowed country"

    # Test with restricted country
    policy = RestrictedContentPolicy.new(@contributor, @content, context: { country: "NotAllowed" })
    refute policy.show?, "Cannot view from restricted country"
    refute policy.update?, "Cannot update from restricted country"
  end

  test "multiple context values can be used together" do
    # Combine multiple context values
    context = {
      ip_address: "192.168.1.1",
      country: "USA",
      two_factor_verified: true,
      user_plan: "pro",
      current_time: Time.new(2024, 1, 1, 14, 0, 0) # 2 PM
    }

    policy = ContextAwarePostPolicy.new(@contributor, @unpublished_post, context: context)

    # Should be able to see (trusted IP)
    assert policy.show?, "Can see with trusted IP"

    # Should be able to create (business hours)
    assert policy.create?, "Can create during business hours"

    # Should be able to update (2FA verified, not restricted country)
    assert policy.update?, "Can update with 2FA from allowed country"

    # Should be able to export (pro plan owner)
    assert policy.export?, "Can export as pro plan owner"
  end

  test "context can be nil or empty without breaking policies" do
    # Nil context
    policy = ContextAwarePostPolicy.new(@contributor, @published_post, context: nil)
    assert policy.show?, "Works with nil context"

    # Empty context
    policy = ContextAwarePostPolicy.new(@contributor, @published_post, context: {})
    assert policy.show?, "Works with empty context"

    # No context parameter at all
    policy = ContextAwarePostPolicy.new(@contributor, @published_post)
    assert policy.show?, "Works without context parameter"
  end

  test "context is isolated between policy instances" do
    # Create two policies with different contexts
    policy1 = ContextAwarePostPolicy.new(@contributor, @published_post, context: { user_plan: "enterprise" })
    policy2 = ContextAwarePostPolicy.new(@contributor, @published_post, context: { user_plan: "basic" })

    # Each should use its own context
    assert policy1.export?, "Policy 1 uses enterprise context"
    refute policy2.export?, "Policy 2 uses basic context"
  end
end
