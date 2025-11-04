# Policy for Post authorization
class PostPolicy < ApplicationPolicy
  # Anyone can view the index of posts
  def index?
    true
  end

  # Show logic:
  # - Guests/viewers can see published posts
  # - Authors can see their own posts (published or draft)
  # - Moderators and admins can see all posts
  def show?
    return true if admin? || moderator?
    return true if record.published?
    owner? && author?
  end

  # Only authors and admins can create posts
  def create?
    logged_in? && (author? || admin?)
  end

  # Users can edit their own posts, admins can edit all
  def update?
    return true if admin?
    owner? && author?
  end

  # Same as update - own posts or admin
  def destroy?
    update?
  end

  # Custom action: publish a post
  # Authors can publish their own posts, admins can publish any
  def publish?
    return true if admin?
    owner? && author?
  end

  # Custom action: unpublish a post
  def unpublish?
    publish?
  end

  # Permitted attributes for strong parameters
  def permitted_attributes
    if admin?
      [:title, :body, :excerpt, :published, :user_id]
    elsif author? && owner?
      [:title, :body, :excerpt]
    else
      []
    end
  end

  # For create action, authors can't set user_id (will be set to current_user)
  def permitted_attributes_for_create
    if admin?
      [:title, :body, :excerpt, :published, :user_id]
    elsif author?
      [:title, :body, :excerpt]
    else
      []
    end
  end

  # For update, same as general permitted_attributes
  def permitted_attributes_for_update
    permitted_attributes
  end

  # Visible attributes - what the user can see
  def visible_attributes
    if admin? || (author? && owner?)
      [:id, :title, :body, :excerpt, :published, :user_id, :created_at, :updated_at]
    elsif logged_in?
      [:id, :title, :body, :excerpt, :created_at]
    else
      [:id, :title, :excerpt]
    end
  end

  # For index action, show less detail
  def visible_attributes_for_index
    [:id, :title, :excerpt, :created_at]
  end

  # For show action, show full detail based on role
  def visible_attributes_for_show
    visible_attributes
  end

  # Editable attributes
  def editable_attributes
    if admin?
      [:title, :body, :excerpt, :published]
    elsif author? && owner?
      [:title, :body, :excerpt]
    else
      []
    end
  end

  # Scope for filtering collections
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Admins and moderators see all posts
      return scope.all if admin? || moderator?

      # Authors see published posts + their own drafts
      if author?
        scope.where("published = ? OR user_id = ?", true, user&.id)
      else
        # Guests and viewers see only published posts
        scope.where(published: true)
      end
    end

    protected

    def author?
      user&.author?
    end

    def moderator?
      user&.moderator?
    end
  end

  protected

  def author?
    user&.author?
  end

  def moderator?
    user&.moderator?
  end
end
