# frozen_string_literal: true

require "test_helper"
require "ostruct"

class ApiSupportTest < ActiveSupport::TestCase
  def setup
    @user = User.new(id: 1, role: :viewer)
    @admin = User.new(id: 2, role: :admin)
    @post = Post.new(id: 1, user_id: 2)
  end

  def teardown
    SimpleAuthorize.reset_configuration!
  end

  # JSON Request Tests

  test "returns JSON error response for unauthorized JSON request" do
    controller = JsonController.new(@user)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    response = controller.handle_api_authorization_error(error)

    assert_equal 403, response[:status]
    assert_equal "application/json", response[:content_type]
    assert_kind_of Hash, response[:body]
    assert_equal "not_authorized", response[:body][:error]
    assert_equal "You are not authorized to perform this action.", response[:body][:message]
  end

  test "JSON error includes detailed information when configured" do
    SimpleAuthorize.configure do |config|
      config.api_error_details = true
    end

    controller = JsonController.new(@user)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    response = controller.handle_api_authorization_error(error)

    assert_equal "update?", response[:body][:query]
    assert_equal "Post", response[:body][:record_type]
    assert_equal "PostPolicy", response[:body][:policy]
  end

  test "JSON error does not include details by default" do
    controller = JsonController.new(@user)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    response = controller.handle_api_authorization_error(error)

    refute response[:body].key?(:query)
    refute response[:body].key?(:record_type)
    refute response[:body].key?(:policy)
  end

  test "returns 403 Forbidden for authorization failures" do
    controller = JsonController.new(@user)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    response = controller.handle_api_authorization_error(error)

    assert_equal 403, response[:status]
  end

  test "returns 401 Unauthorized when user is nil" do
    controller = JsonController.new(nil)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :create?)
    end

    response = controller.handle_api_authorization_error(error)

    assert_equal 401, response[:status]
  end

  test "custom error message can be configured" do
    SimpleAuthorize.configure do |config|
      config.default_error_message = "Access denied!"
    end

    controller = JsonController.new(@user)

    error = assert_raises(SimpleAuthorize::Controller::NotAuthorizedError) do
      controller.authorize(@post, :update?)
    end

    response = controller.handle_api_authorization_error(error)

    assert_equal "Access denied!", response[:body][:message]
  end

  # Format Detection Tests

  test "detects JSON format from request format" do
    controller = JsonController.new(@user)

    assert controller.api_request?
  end

  test "detects XML format as API request" do
    controller = XmlController.new(@user)

    assert controller.api_request?
  end

  test "HTML format is not detected as API request" do
    controller = HtmlController.new(@user)

    refute controller.api_request?
  end

  test "detects JSON from Accept header" do
    controller = MockControllerWithHeaders.new(@user, "Accept" => "application/json")

    assert controller.api_request?
  end

  test "detects JSON from Content-Type header" do
    controller = MockControllerWithHeaders.new(@user, "Content-Type" => "application/json")

    assert controller.api_request?
  end

  # Integration Tests

  test "rescue_from_authorization_errors handles both HTML and API" do
    # This would be tested in a full Rails integration test
    # Here we just verify the methods exist
    assert HtmlController.respond_to?(:rescue_from_authorization_errors)
  end

  test "api_error_response helper formats response correctly" do
    controller = JsonController.new(@user)

    response = controller.api_error_response(
      message: "Custom error",
      status: 422,
      details: { field: "email" }
    )

    assert_equal 422, response[:status]
    assert_equal "Custom error", response[:body][:message]
    assert_equal({ field: "email" }, response[:body][:details])
  end

  # Helper mock controller classes for testing

  class JsonController
    include SimpleAuthorize::Controller

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def action_name
      "update"
    end

    def request_format
      :json
    end

    def request
      OpenStruct.new(format: OpenStruct.new(json?: true, xml?: false, html?: false))
    end
  end

  class XmlController
    include SimpleAuthorize::Controller

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def action_name
      "update"
    end

    def request
      OpenStruct.new(format: OpenStruct.new(json?: false, xml?: true, html?: false))
    end
  end

  class HtmlController
    include SimpleAuthorize::Controller

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def action_name
      "update"
    end

    def request
      OpenStruct.new(format: OpenStruct.new(json?: false, xml?: false, html?: true))
    end
  end

  class MockControllerWithHeaders
    include SimpleAuthorize::Controller

    attr_reader :current_user, :headers

    def initialize(user, headers = {})
      @current_user = user
      @headers = headers
    end

    def action_name
      "update"
    end

    def request
      OpenStruct.new(
        format: OpenStruct.new(json?: false, xml?: false, html?: true),
        headers: @headers
      )
    end
  end
end
