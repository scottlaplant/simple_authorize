# frozen_string_literal: true

# Start SimpleCov before anything else
require "simplecov"
SimpleCov.command_name "Minitest"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simple_authorize"

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_model"
require "action_controller"
require "ostruct"

# Include test helpers in all test cases
module ActiveSupport
  class TestCase
    include SimpleAuthorize::TestHelpers
  end
end

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

  def model_name
    self.class.model_name
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
      %i[title body published]
    else
      %i[title body]
    end
  end

  def visible_attributes
    if user&.admin?
      %i[id title body published user_id]
    elsif user.present?
      %i[id title body published]
    else
      []
    end
  end

  def visible_attributes_for_index
    if user&.admin?
      %i[id title published]
    else
      %i[id title]
    end
  end

  def visible_attributes_for_show
    visible_attributes
  end

  def editable_attributes
    if user&.admin?
      %i[title body published]
    elsif user&.contributor?
      %i[title body]
    else
      []
    end
  end

  def editable_attributes_for_create
    if user&.admin?
      %i[title body published]
    elsif user&.contributor?
      %i[title body]
    else
      []
    end
  end

  def editable_attributes_for_update
    editable_attributes
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
