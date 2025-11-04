# Example User model for blog application
#
# In a real Rails app, this would be in app/models/user.rb
# and likely use Devise or another authentication gem.
class User < ApplicationRecord
  ROLES = %w[admin author moderator viewer].freeze

  validates :role, inclusion: { in: ROLES }

  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy

  def admin?
    role == "admin"
  end

  def author?
    role == "author"
  end

  def moderator?
    role == "moderator"
  end

  def viewer?
    role == "viewer"
  end

  # Helper methods for authorization
  def can_create_content?
    admin? || author?
  end

  def can_moderate?
    admin? || moderator?
  end
end
