# frozen_string_literal: true

require "test_helper"
require "active_support/notifications"

class InstrumentationTest < ActiveSupport::TestCase
  def setup
    @user = User.new(id: 1, role: :admin)
    @post = Post.new(id: 1, user_id: 1)
    @controller = MockController.new(@user)
    @events = []

    # Subscribe to authorization events
    @subscriber = ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |name, start, finish, _id, payload| # rubocop:disable Layout/LineLength
      @events << {
        name: name,
        duration: finish - start,
        payload: payload
      }
    end
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
    @events = []
  end

  test "authorize emits instrumentation event on success" do
    @controller.authorize(@post, :show?)

    assert_equal 1, @events.size
    event = @events.first

    assert_equal "authorize.simple_authorize", event[:name]
    assert_equal @user, event[:payload][:user]
    assert_equal @post, event[:payload][:record]
    assert_equal "show?", event[:payload][:query]
    assert_equal PostPolicy, event[:payload][:policy_class]
    assert_equal true, event[:payload][:authorized]
    assert_nil event[:payload][:error]
  end

  test "authorize emits instrumentation event on failure" do
    user = User.new(id: 2, role: :viewer)
    controller = MockController.new(user)
    post = Post.new(id: 1, user_id: 1)

    assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(post, :update?)
    end

    assert_equal 1, @events.size
    event = @events.first

    assert_equal "authorize.simple_authorize", event[:name]
    assert_equal user, event[:payload][:user]
    assert_equal post, event[:payload][:record]
    assert_equal "update?", event[:payload][:query]
    assert_equal PostPolicy, event[:payload][:policy_class]
    assert_equal false, event[:payload][:authorized]
    assert_instance_of SimpleAuthorize::Controller::NotAuthorizedError, event[:payload][:error]
  end

  test "policy_scope emits instrumentation event" do
    @controller.policy_scope(Post)

    assert_equal 1, @events.size
    event = @events.first

    assert_equal "policy_scope.simple_authorize", event[:name]
    assert_equal @user, event[:payload][:user]
    assert_equal Post, event[:payload][:scope]
    assert_equal PostPolicy::Scope, event[:payload][:policy_scope_class]
    assert_nil event[:payload][:error]
  end

  test "instrumentation includes controller and action info when available" do
    @controller.authorize(@post, :show?)

    event = @events.first
    assert_equal "MockController", event[:payload][:controller]
    assert_equal "index", event[:payload][:action]
  end

  test "instrumentation includes user id when available" do
    @controller.authorize(@post, :show?)

    event = @events.first
    assert_equal 1, event[:payload][:user_id]
  end

  test "instrumentation includes record id and class when available" do
    @controller.authorize(@post, :show?)

    event = @events.first
    assert_equal 1, event[:payload][:record_id]
    assert_equal "Post", event[:payload][:record_class]
  end

  test "instrumentation works when user is nil" do
    controller = MockController.new(nil)

    assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :create?)
    end

    event = @events.first
    assert_nil event[:payload][:user]
    assert_nil event[:payload][:user_id]
  end

  test "authorize_headless emits instrumentation event" do
    @controller.authorize_headless(PostPolicy, :index?)

    assert_equal 1, @events.size
    event = @events.first

    assert_equal "authorize.simple_authorize", event[:name]
    assert_equal @user, event[:payload][:user]
    assert_nil event[:payload][:record]
    assert_equal "index?", event[:payload][:query]
    assert_equal PostPolicy, event[:payload][:policy_class]
    assert_equal true, event[:payload][:authorized]
  end

  test "multiple authorizations emit multiple events" do
    post1 = Post.new(id: 1, user_id: 1)
    post2 = Post.new(id: 2, user_id: 1)

    @controller.authorize(post1, :show?)
    @controller.authorize(post2, :show?)
    @controller.policy_scope(Post)

    assert_equal 3, @events.size
    assert_equal "authorize.simple_authorize", @events[0][:name]
    assert_equal "authorize.simple_authorize", @events[1][:name]
    assert_equal "policy_scope.simple_authorize", @events[2][:name]
  end

  test "custom subscriber can process events" do
    results = []

    ActiveSupport::Notifications.subscribe("authorize.simple_authorize") do |_name, _start, _finish, _id, payload|
      user_id = payload[:user_id]
      query = payload[:query]
      record = "#{payload[:record_class]}##{payload[:record_id]}"
      authorized = payload[:authorized]
      results << "User #{user_id} attempted #{query} on #{record}: #{authorized}"
    end

    @controller.authorize(@post, :show?)

    assert_equal 1, results.size
    assert_equal "User 1 attempted show? on Post#1: true", results.first
  end

  test "instrumentation can be disabled via configuration" do
    SimpleAuthorize.configure do |config|
      config.enable_instrumentation = false
    end

    @controller.authorize(@post, :show?)

    assert_equal 0, @events.size
  ensure
    SimpleAuthorize.reset_configuration!
  end

  test "instrumentation is enabled by default" do
    assert SimpleAuthorize.configuration.enable_instrumentation
  end

  # Helper mock controller class for testing
  class MockController
    include SimpleAuthorize::Controller

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    # Mock action_name for testing
    def action_name
      "index"
    end

    # Mock controller_name for testing
    def controller_name
      self.class.name
    end
  end
end
