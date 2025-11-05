# frozen_string_literal: true

require "test_helper"

class PolicyCompositionTest < ActiveSupport::TestCase
  # Setup test modules that can be mixed into policies
  module Ownable
    def update?
      owner? || admin?
    end

    def destroy?
      owner? || admin?
    end

    private

    def owner?
      user&.id == record.user_id
    end
  end

  module Publishable
    def publish?
      admin? || (owner? && contributor?)
    end

    def unpublish?
      admin? || owner?
    end

    def schedule?
      admin? || (owner? && record.respond_to?(:scheduled_at))
    end

    def visible_attributes
      if record.published?
        super
      else
        super - [:internal_notes]
      end
    end
  end

  module Approvable
    def approve?
      admin? || (contributor? && !owner?)
    end

    def reject?
      admin? || (contributor? && !owner?)
    end

    def request_approval?
      owner? && record.respond_to?(:pending_approval)
    end
  end

  module TimeBased
    def update?
      return false if record_expired?

      super
    end

    def destroy?
      return false if record_locked?

      super
    end

    private

    def record_expired?
      record.respond_to?(:expired_at) && record.expired_at && record.expired_at < Time.current
    end

    def record_locked?
      record.respond_to?(:locked_at) && record.locked_at && record.locked_at < Time.current
    end
  end

  module SoftDeletable
    def destroy?
      # Soft delete instead of hard delete
      soft_delete? && super
    end

    def restore?
      admin? && record.respond_to?(:deleted_at)
    end

    def permanently_destroy?
      admin?
    end

    private

    def soft_delete?
      record.respond_to?(:deleted_at)
    end
  end

  # Test policy that uses composition
  class ArticlePolicy < SimpleAuthorize::Policy
    include Ownable
    include Publishable

    def index?
      true
    end

    def show?
      record.published || owner? || admin?
    end

    def create?
      contributor? || admin?
    end
  end

  # Another test policy with different module combination
  class DocumentPolicy < SimpleAuthorize::Policy
    include Ownable
    include Approvable
    include TimeBased

    def index?
      logged_in?
    end

    def show?
      true
    end

    def create?
      contributor? || admin?
    end
  end

  # Policy with all modules for comprehensive testing
  class ContentPolicy < SimpleAuthorize::Policy
    include Ownable
    include Publishable
    include Approvable
    include TimeBased
    include SoftDeletable

    def index?
      true
    end

    def show?
      true
    end

    def create?
      logged_in?
    end
  end

  def setup
    @admin = User.new(id: 1, role: :admin)
    @contributor = User.new(id: 2, role: :contributor)
    @viewer = User.new(id: 3, role: :viewer)
    @owner = User.new(id: 4, role: :contributor)

    @article = OpenStruct.new(
      id: 1,
      user_id: 4,
      published: true,
      internal_notes: "secret"
    )

    @unpublished_article = OpenStruct.new(
      id: 2,
      user_id: 4,
      published: false,
      internal_notes: "secret"
    )

    @document = OpenStruct.new(
      id: 1,
      user_id: 4,
      pending_approval: true
    )

    @expired_document = OpenStruct.new(
      id: 2,
      user_id: 4,
      expired_at: 1.day.ago
    )

    @locked_document = OpenStruct.new(
      id: 3,
      user_id: 4,
      locked_at: 1.hour.ago
    )
  end

  # Test Ownable module
  test "Ownable module provides owner-based authorization" do
    policy = ArticlePolicy.new(@owner, @article)
    assert policy.update?, "Owner should be able to update"
    assert policy.destroy?, "Owner should be able to destroy"

    policy = ArticlePolicy.new(@contributor, @article)
    refute policy.update?, "Non-owner contributor should not update"
    refute policy.destroy?, "Non-owner contributor should not destroy"

    policy = ArticlePolicy.new(@admin, @article)
    assert policy.update?, "Admin should always update"
    assert policy.destroy?, "Admin should always destroy"
  end

  # Test Publishable module
  test "Publishable module provides publishing authorization" do
    policy = ArticlePolicy.new(@owner, @article)
    assert policy.publish?, "Owner contributor should publish"
    assert policy.unpublish?, "Owner should unpublish"

    policy = ArticlePolicy.new(@contributor, @article)
    refute policy.publish?, "Non-owner contributor should not publish"
    refute policy.unpublish?, "Non-owner should not unpublish"

    policy = ArticlePolicy.new(@admin, @article)
    assert policy.publish?, "Admin should publish"
    assert policy.unpublish?, "Admin should unpublish"
  end

  test "Publishable module filters attributes based on published state" do
    policy = ArticlePolicy.new(@viewer, @unpublished_article)
    attributes = policy.visible_attributes
    refute_includes attributes, :internal_notes, "Internal notes should be hidden for unpublished articles"
  end

  # Test Approvable module
  test "Approvable module provides approval authorization" do
    policy = DocumentPolicy.new(@contributor, @document)
    assert policy.approve?, "Non-owner contributor can approve"
    assert policy.reject?, "Non-owner contributor can reject"

    policy = DocumentPolicy.new(@owner, @document)
    refute policy.approve?, "Owner cannot approve their own content"
    refute policy.reject?, "Owner cannot reject their own content"
    assert policy.request_approval?, "Owner can request approval"

    policy = DocumentPolicy.new(@admin, @document)
    assert policy.approve?, "Admin can approve"
    assert policy.reject?, "Admin can reject"
  end

  # Test TimeBased module
  test "TimeBased module restricts based on expiration" do
    policy = DocumentPolicy.new(@owner, @expired_document)
    refute policy.update?, "Cannot update expired document"

    policy = DocumentPolicy.new(@owner, @document)
    assert policy.update?, "Can update non-expired document"
  end

  test "TimeBased module restricts based on lock status" do
    policy = DocumentPolicy.new(@owner, @locked_document)
    refute policy.destroy?, "Cannot destroy locked document"

    policy = DocumentPolicy.new(@owner, @document)
    assert policy.destroy?, "Can destroy unlocked document"
  end

  # Test SoftDeletable module
  test "SoftDeletable module provides soft delete functionality" do
    soft_deletable = OpenStruct.new(
      id: 1,
      user_id: 4,
      deleted_at: nil
    )

    policy = ContentPolicy.new(@owner, soft_deletable)
    assert policy.destroy?, "Can soft delete if record supports it"
    refute policy.restore?, "Non-admin cannot restore"
    refute policy.permanently_destroy?, "Non-admin cannot permanently destroy"

    policy = ContentPolicy.new(@admin, soft_deletable)
    assert policy.restore?, "Admin can restore"
    assert policy.permanently_destroy?, "Admin can permanently destroy"
  end

  # Test module interaction and precedence
  test "modules can work together without conflicts" do
    content = OpenStruct.new(
      id: 1,
      user_id: 4,
      published: false,
      pending_approval: true,
      expired_at: nil,
      locked_at: nil,
      deleted_at: nil
    )

    policy = ContentPolicy.new(@owner, content)

    # From Ownable
    assert policy.update?, "Owner can update (via Ownable)"

    # From Publishable
    assert policy.publish?, "Owner contributor can publish"

    # From Approvable
    assert policy.request_approval?, "Owner can request approval"

    # From SoftDeletable
    assert policy.destroy?, "Can soft delete"
  end

  test "module methods can call super to extend base behavior" do
    expired_content = OpenStruct.new(
      id: 1,
      user_id: 4,
      expired_at: 1.day.ago
    )

    policy = ContentPolicy.new(@owner, expired_content)
    refute policy.update?, "TimeBased module prevents update when expired"

    policy = ContentPolicy.new(@admin, expired_content)
    refute policy.update?, "Even admin cannot update expired content"
  end

  # Test that composition doesn't break base functionality
  test "composed policies still have access to base policy helpers" do
    # Test that helpers work indirectly through public methods that use them
    policy = ArticlePolicy.new(@admin, @article)
    assert policy.create?, "Admin can create (uses admin? helper internally)"
    assert policy.show?, "Admin can always view (uses admin? helper internally)"

    policy = ArticlePolicy.new(@contributor, @article)
    assert policy.create?, "Contributor can create (uses contributor? helper internally)"

    policy = ArticlePolicy.new(@viewer, @article)
    refute policy.create?, "Viewer cannot create (verifies role helpers work)"
    assert policy.show?, "Viewer can see published articles"

    # Test logged_in? helper indirectly
    policy = ArticlePolicy.new(nil, @article)
    refute policy.update?, "Non-logged in user cannot update (logged_in? returns false)"
  end

  # Test module inclusion order matters for overriding
  test "module inclusion order affects method precedence" do
    class OrderTestPolicy1 < SimpleAuthorize::Policy
      include Ownable
      include TimeBased # TimeBased will override Ownable's update?
    end

    class OrderTestPolicy2 < SimpleAuthorize::Policy
      include TimeBased
      include Ownable # Ownable will override TimeBased's update?
    end

    expired_doc = OpenStruct.new(
      id: 1,
      user_id: 4,
      expired_at: 1.day.ago
    )

    # TimeBased is included last, so it wins
    policy1 = OrderTestPolicy1.new(@owner, expired_doc)
    refute policy1.update?, "TimeBased prevents update when expired"

    # Ownable is included last, so it wins (ignores expiration)
    policy2 = OrderTestPolicy2.new(@owner, expired_doc)
    assert policy2.update?, "Ownable allows update for owner regardless of expiration"
  end

  # Test that we can use modules from external sources
  test "policies can include modules from gems or other sources" do
    # Simulating an external module
    module ExternalAuthModule
      def special_permission?
        user.respond_to?(:special_role) && user.special_role == "special"
      end
    end

    class ExternalModulePolicy < SimpleAuthorize::Policy
      include ExternalAuthModule
      include Ownable

      def perform_special_action?
        special_permission? || admin?
      end
    end

    special_user = OpenStruct.new(id: 5, role: :viewer, special_role: "special")
    policy = ExternalModulePolicy.new(special_user, @article)

    assert policy.special_permission?, "External module method works"
    assert policy.perform_special_action?, "Can use external module in policy methods"
  end

  # Test composition with scope
  test "composed policies work with scopes" do
    class ArticleWithScopePolicy < SimpleAuthorize::Policy
      include Ownable
      include Publishable

      class Scope < SimpleAuthorize::Policy::Scope
        def resolve
          if user&.admin?
            scope.all
          elsif user&.contributor?
            scope.where(published: true).or(scope.where(user_id: user.id))
          else
            scope.where(published: true)
          end
        end
      end
    end

    # We'll test that the scope class is accessible
    assert ArticleWithScopePolicy::Scope, "Scope class should be defined"

    # Create a mock scope
    mock_scope = Minitest::Mock.new
    mock_scope.expect :all, "all_records"

    scope = ArticleWithScopePolicy::Scope.new(@admin, mock_scope)
    assert_equal "all_records", scope.resolve
  end
end
