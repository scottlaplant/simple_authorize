# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simple_authorize"

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_model"

# Mock objects for testing
class User
  attr_accessor :id, :role

  def initialize(id: 1, role: :viewer)
    @id = id
    @role = role
  end

  def admin?
    role == :admin
  end

  def contributor?
    role == :contributor
  end

  def viewer?
    role == :viewer
  end

  def can_create_content?
    admin? || contributor?
  end

  def can_manage_content?
    admin?
  end
end

class Post
  attr_accessor :id, :user_id, :published

  def initialize(id: 1, user_id: 1, published: true)
    @id = id
    @user_id = user_id
    @published = published
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "Post")
  end
end

# Sample policy used across tests
class PostPolicy < SimpleAuthorize::Policy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present? && user.can_create_content?
  end

  def update?
    user.present? && (owner? || user.admin?)
  end

  def destroy?
    user.present? && (owner? || user.admin?)
  end

  def publish?
    user&.admin? || (user&.contributor? && owner?)
  end

  def permitted_attributes
    if user&.admin?
      [:title, :body, :published]
    else
      [:title, :body]
    end
  end

  class Scope < SimpleAuthorize::Policy::Scope
    def resolve
      if user&.admin?
        scope
      else
        scope.select(&:published)
      end
    end
  end
end
