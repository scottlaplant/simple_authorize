# frozen_string_literal: true

require "test_helper"

class TestHelpersTest < ActiveSupport::TestCase
  def setup
    @admin = User.new(id: 1, role: :admin)
    @contributor = User.new(id: 2, role: :contributor)
    @viewer = User.new(id: 3, role: :viewer)
    @post = Post.new(id: 1, user_id: 2)
  end

  # assert_permit_action Tests

  test "assert_permit_action passes when action is permitted" do
    policy = PostPolicy.new(@admin, @post)

    assert_nothing_raised do
      assert_permit_action(policy, :destroy)
    end
  end

  test "assert_permit_action fails when action is not permitted" do
    policy = PostPolicy.new(@viewer, @post)

    error = assert_raises(Minitest::Assertion) do
      assert_permit_action(policy, :destroy)
    end

    assert_match(/Expected.*to permit action :destroy/, error.message)
  end

  test "assert_permit_action works with string actions" do
    policy = PostPolicy.new(@admin, @post)

    assert_nothing_raised do
      assert_permit_action(policy, "show")
    end
  end

  # assert_forbid_action Tests

  test "assert_forbid_action passes when action is forbidden" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      assert_forbid_action(policy, :destroy)
    end
  end

  test "assert_forbid_action fails when action is permitted" do
    policy = PostPolicy.new(@admin, @post)

    error = assert_raises(Minitest::Assertion) do
      assert_forbid_action(policy, :show)
    end

    assert_match(/Expected.*to forbid action :show/, error.message)
  end

  test "assert_forbid_action works with string actions" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      assert_forbid_action(policy, "update")
    end
  end

  # assert_permit_viewing Tests

  test "assert_permit_viewing passes when attribute is visible" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      assert_permit_viewing(policy, :title)
    end
  end

  test "assert_permit_viewing fails when attribute is not visible" do
    policy = PostPolicy.new(@viewer, @post)

    error = assert_raises(Minitest::Assertion) do
      assert_permit_viewing(policy, :user_id)
    end

    assert_match(/Expected.*to permit viewing :user_id/, error.message)
  end

  test "assert_permit_viewing works with string attributes" do
    policy = PostPolicy.new(@admin, @post)

    assert_nothing_raised do
      assert_permit_viewing(policy, "title")
    end
  end

  # assert_forbid_viewing Tests

  test "assert_forbid_viewing passes when attribute is not visible" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      assert_forbid_viewing(policy, :user_id)
    end
  end

  test "assert_forbid_viewing fails when attribute is visible" do
    policy = PostPolicy.new(@admin, @post)

    error = assert_raises(Minitest::Assertion) do
      assert_forbid_viewing(policy, :title)
    end

    assert_match(/Expected.*to forbid viewing :title/, error.message)
  end

  test "assert_forbid_viewing works with string attributes" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      assert_forbid_viewing(policy, "user_id")
    end
  end

  # assert_permit_editing Tests

  test "assert_permit_editing passes when attribute is editable" do
    policy = PostPolicy.new(@contributor, @post)

    assert_nothing_raised do
      assert_permit_editing(policy, :title)
    end
  end

  test "assert_permit_editing fails when attribute is not editable" do
    policy = PostPolicy.new(@contributor, @post)

    error = assert_raises(Minitest::Assertion) do
      assert_permit_editing(policy, :published)
    end

    assert_match(/Expected.*to permit editing :published/, error.message)
  end

  test "assert_permit_editing works with string attributes" do
    policy = PostPolicy.new(@admin, @post)

    assert_nothing_raised do
      assert_permit_editing(policy, "body")
    end
  end

  # assert_forbid_editing Tests

  test "assert_forbid_editing passes when attribute is not editable" do
    policy = PostPolicy.new(@contributor, @post)

    assert_nothing_raised do
      assert_forbid_editing(policy, :published)
    end
  end

  test "assert_forbid_editing fails when attribute is editable" do
    policy = PostPolicy.new(@admin, @post)

    error = assert_raises(Minitest::Assertion) do
      assert_forbid_editing(policy, :title)
    end

    assert_match(/Expected.*to forbid editing :title/, error.message)
  end

  test "assert_forbid_editing works with string attributes" do
    policy = PostPolicy.new(@viewer, @post)

    assert_nothing_raised do
      assert_forbid_editing(policy, "published")
    end
  end

  # Edge Cases

  test "helpers work with nil user" do
    policy = PostPolicy.new(nil, @post)

    assert_nothing_raised do
      assert_forbid_action(policy, :update)
      assert_forbid_viewing(policy, :title)
      assert_forbid_editing(policy, :body)
    end
  end

  test "helpers handle missing policy methods gracefully" do
    policy = PostPolicy.new(@admin, @post)

    error = assert_raises(NoMethodError) do
      assert_permit_action(policy, :nonexistent_action)
    end

    assert_match(/undefined method/, error.message)
  end
end
