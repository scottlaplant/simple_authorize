# Example Comment model for blog application
class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user

  validates :body, presence: true

  scope :approved, -> { where(approved: true) }
  scope :pending, -> { where(approved: false) }

  def approved?
    approved == true
  end

  def pending?
    !approved?
  end
end
