# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/simple_authorize/policy/policy_generator"

class PolicyGeneratorTest < Rails::Generators::TestCase
  tests SimpleAuthorize::Generators::PolicyGenerator
  destination File.expand_path("../../tmp", __dir__)
  setup :prepare_destination

  test "generates policy file" do
    run_generator ["post"]

    assert_file "app/policies/post_policy.rb" do |content|
      assert_match(/class PostPolicy < ApplicationPolicy/, content)
      assert_match(/def index\?/, content)
      assert_match(/def show\?/, content)
      assert_match(/def create\?/, content)
      assert_match(/def update\?/, content)
      assert_match(/def destroy\?/, content)
    end
  end

  test "generates policy with scope class" do
    run_generator ["post"]

    assert_file "app/policies/post_policy.rb" do |content|
      assert_match(/class Scope < ApplicationPolicy::Scope/, content)
      assert_match(/def resolve/, content)
    end
  end

  test "generates policy with correct class name for multi-word models" do
    run_generator ["blog_post"]

    assert_file "app/policies/blog_post_policy.rb" do |content|
      assert_match(/class BlogPostPolicy < ApplicationPolicy/, content)
    end
  end

  test "generates policy with namespaced model" do
    run_generator ["admin/post"]

    assert_file "app/policies/admin/post_policy.rb" do |content|
      assert_match(/class Admin::PostPolicy < ApplicationPolicy/, content)
    end
  end

  test "generates spec file when using rspec" do
    run_generator ["post", "--spec"]

    assert_file "spec/policies/post_policy_spec.rb" do |content|
      assert_match(/RSpec.describe PostPolicy/, content)
      assert_match(/describe "#index\?"/, content)
      assert_match(/describe "#show\?"/, content)
      assert_match(/describe "#create\?"/, content)
      assert_match(/describe "#update\?"/, content)
      assert_match(/describe "#destroy\?"/, content)
    end
  end

  test "generates test file by default" do
    run_generator ["post"]

    assert_file "test/policies/post_policy_test.rb" do |content|
      assert_match(/class PostPolicyTest < ActiveSupport::TestCase/, content)
      assert_match(/test "index\?"/, content)
      assert_match(/test "show\?"/, content)
      assert_match(/test "create\?"/, content)
      assert_match(/test "update\?"/, content)
      assert_match(/test "destroy\?"/, content)
    end
  end

  test "generates test with scope tests" do
    run_generator ["post"]

    assert_file "test/policies/post_policy_test.rb" do |content|
      assert_match(/test "scope"/, content)
    end
  end

  test "skips test when --skip-test is provided" do
    run_generator ["post", "--skip-test"]

    assert_no_file "test/policies/post_policy_test.rb"
    assert_no_file "spec/policies/post_policy_spec.rb"
  end

  test "generates policy with permitted_attributes method" do
    run_generator ["post"]

    assert_file "app/policies/post_policy.rb" do |content|
      assert_match(/def permitted_attributes/, content)
    end
  end

  test "creates all expected files" do
    run_generator ["post"]

    assert_file "app/policies/post_policy.rb"
    assert_file "test/policies/post_policy_test.rb"
  end
end
