# Example Post model for blog application
class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :body, presence: true

  scope :published, -> { where(published: true) }
  scope :drafts, -> { where(published: false) }

  def published?
    published == true
  end

  def draft?
    !published?
  end

  def author
    user
  end
end
