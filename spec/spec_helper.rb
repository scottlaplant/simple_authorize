# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simple_authorize"
require "simple_authorize/rspec"
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

# Sample policy used across specs
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

  def visible_attributes
    if user&.admin?
      %i[id title body published user_id]
    elsif user.present?
      %i[id title body published]
    else
      []
    end
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
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end
