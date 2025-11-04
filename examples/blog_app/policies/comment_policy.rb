# Policy for Comment authorization
class CommentPolicy < ApplicationPolicy
  # Anyone can view approved comments
  def index?
    true
  end

  # Show logic:
  # - Everyone can see approved comments
  # - Moderators and admins can see all comments
  # - Comment owners can see their own comments
  # - Post authors can see comments on their posts
  def show?
    return true if admin? || moderator?
    return true if record.approved?
    return true if owner?
    post_owner?
  end

  # Logged-in users can create comments
  def create?
    logged_in?
  end

  # Users can edit their own comments
  # Admins can edit any comment
  def update?
    return true if admin?
    owner?
  end

  # Only moderators and admins can destroy comments
  def destroy?
    admin? || moderator?
  end

  # Custom action: approve a comment
  # Post authors can approve comments on their posts
  # Moderators and admins can approve any comment
  def approve?
    return true if admin? || moderator?
    post_owner?
  end

  # Custom action: reject/unapprove a comment
  def reject?
    approve?
  end

  # Permitted attributes
  def permitted_attributes
    if admin? || moderator?
      [:body, :approved]
    elsif owner?
      [:body]
    else
      []
    end
  end

  # For create, users can only set body
  def permitted_attributes_for_create
    [:body]
  end

  # For update, owners can only edit body
  def permitted_attributes_for_update
    if admin? || moderator?
      [:body, :approved]
    elsif owner?
      [:body]
    else
      []
    end
  end

  # Visible attributes
  def visible_attributes
    if admin? || moderator? || owner? || post_owner?
      [:id, :body, :approved, :user_id, :post_id, :created_at, :updated_at]
    else
      [:id, :body, :created_at]
    end
  end

  # Editable attributes
  def editable_attributes
    if admin? || moderator?
      [:body, :approved]
    elsif owner?
      [:body]
    else
      []
    end
  end

  # Scope for filtering collections
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Admins and moderators see all comments
      return scope.all if admin? || moderator?

      # Everyone else sees only approved comments
      # (Note: In a real app, you might want to show users their own pending comments)
      scope.where(approved: true)
    end

    protected

    def moderator?
      user&.moderator?
    end
  end

  protected

  def moderator?
    user&.moderator?
  end

  def post_owner?
    record.post.user_id == user&.id
  end
end
