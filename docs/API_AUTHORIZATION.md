# API Authorization Guide

This guide covers authorization for JSON/XML APIs using SimpleAuthorize.

## Table of Contents

- [Overview](#overview)
- [Basic Setup](#basic-setup)
- [Error Handling](#error-handling)
- [HTTP Status Codes](#http-status-codes)
- [Authentication](#authentication)
- [Response Formats](#response-formats)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)

## Overview

SimpleAuthorize automatically detects API requests and returns appropriate JSON/XML error responses instead of HTML redirects.

### Automatic API Detection

SimpleAuthorize detects API requests based on:
1. Request format (`.json`, `.xml`)
2. `Accept` header (`application/json`, `application/xml`)
3. `Content-Type` header

## Basic Setup

### ApplicationController

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include SimpleAuthorize::Controller

  # Automatically handles authorization errors for API requests
  rescue_from_authorization_errors

  private

  def current_user
    @current_user ||= User.find_by(api_token: request.headers['Authorization']&.split(' ')&.last)
  end
end
```

### API Controller Example

```ruby
# app/controllers/api/v1/posts_controller.rb
module Api
  module V1
    class PostsController < ApplicationController
      before_action :set_post, only: [:show, :update, :destroy]

      def index
        @posts = policy_scope(Post)
        render json: @posts
      end

      def show
        authorize @post
        render json: @post
      end

      def create
        @post = Post.new(post_params)
        authorize @post

        if @post.save
          render json: @post, status: :created
        else
          render json: { errors: @post.errors }, status: :unprocessable_entity
        end
      end

      def update
        authorize @post

        if @post.update(policy_params(@post))
          render json: @post
        else
          render json: { errors: @post.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @post
        @post.destroy
        head :no_content
      end

      private

      def set_post
        @post = Post.find(params[:id])
      end

      def post_params
        params.require(:post).permit(:title, :body)
      end
    end
  end
end
```

## Error Handling

### Default API Error Response

When authorization fails, SimpleAuthorize automatically returns:

**JSON Response:**
```json
{
  "error": "You are not authorized to perform this action."
}
```

**HTTP Status:** `403 Forbidden` (if user is logged in) or `401 Unauthorized` (if no user)

### Custom Error Responses

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include SimpleAuthorize::Controller

  rescue_from SimpleAuthorize::Controller::NotAuthorizedError, with: :handle_unauthorized

  private

  def handle_unauthorized(exception)
    render json: {
      error: {
        message: exception.message,
        type: "authorization_error",
        code: "UNAUTHORIZED"
      }
    }, status: :forbidden
  end
end
```

### Detailed Error Information

Enable detailed error information in development/staging:

```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  config.api_error_details = !Rails.env.production?
end
```

With `api_error_details` enabled:

```json
{
  "error": "You are not authorized to perform this action.",
  "details": {
    "user_id": 123,
    "record_type": "Post",
    "record_id": 456,
    "action": "update",
    "policy": "PostPolicy"
  }
}
```

## HTTP Status Codes

SimpleAuthorize uses appropriate HTTP status codes:

| Scenario | Status Code | Meaning |
|----------|-------------|---------|
| No user (guest) attempting protected action | `401 Unauthorized` | Authentication required |
| Logged-in user lacks permission | `403 Forbidden` | Authenticated but not authorized |
| Policy not found | `500 Internal Server Error` | Server configuration error |
| Record not found | `404 Not Found` | (Handle with ActiveRecord) |

### Example Status Code Handling

```ruby
# In your API client
response = HTTParty.post('/api/posts', body: post_data, headers: headers)

case response.code
when 201
  puts "Created successfully"
when 401
  puts "Please log in"
  redirect_to_login
when 403
  puts "You don't have permission"
  show_error_message
when 422
  puts "Validation errors: #{response['errors']}"
end
```

## Authentication

### Token-Based Authentication

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include SimpleAuthorize::Controller

  before_action :authenticate_user!

  private

  def current_user
    @current_user ||= authenticate_with_token
  end

  def authenticate_with_token
    token = request.headers['Authorization']&.split(' ')&.last
    return nil unless token

    User.find_by(api_token: token)
  end

  def authenticate_user!
    unless current_user
      render json: { error: "Authentication required" }, status: :unauthorized
    end
  end
end
```

### JWT Authentication

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include SimpleAuthorize::Controller

  private

  def current_user
    @current_user ||= begin
      token = request.headers['Authorization']&.split(' ')&.last
      return nil unless token

      decoded = JWT.decode(token, Rails.application.secret_key_base)[0]
      User.find(decoded['user_id'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      nil
    end
  end
end
```

### OAuth2 / Doorkeeper

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include SimpleAuthorize::Controller

  before_action :doorkeeper_authorize!

  private

  def current_user
    @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end
```

## Response Formats

### JSON Responses

#### Success Response

```ruby
# app/controllers/api/v1/posts_controller.rb
def show
  authorize @post

  render json: {
    post: PostSerializer.new(@post).as_json,
    permissions: {
      can_update: policy(@post).update?,
      can_destroy: policy(@post).destroy?,
      can_publish: policy(@post).publish?
    }
  }
end
```

#### With Serializers

```ruby
# app/serializers/post_serializer.rb
class PostSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :created_at

  # Include only visible attributes
  def attributes(*args)
    data = super
    policy = PostPolicy.new(current_user, object)

    data.select do |key, _|
      policy.attribute_visible?(key)
    end
  end

  def current_user
    scope
  end
end

# In controller
render json: @post, serializer: PostSerializer, scope: current_user
```

### XML Responses

```ruby
def show
  authorize @post

  respond_to do |format|
    format.json { render json: @post }
    format.xml { render xml: @post }
  end
end
```

### Error Response Formats

```ruby
# Custom error handler with consistent format
def handle_unauthorized(exception)
  error_response = {
    error: {
      message: exception.message,
      code: "FORBIDDEN",
      timestamp: Time.current.iso8601
    }
  }

  respond_to do |format|
    format.json { render json: error_response, status: :forbidden }
    format.xml { render xml: error_response, status: :forbidden }
  end
end
```

## Best Practices

### 1. Always Scope Collections

```ruby
# ✅ Good
def index
  @posts = policy_scope(Post)
  render json: @posts
end

# ❌ Bad
def index
  @posts = Post.all  # Leaks unauthorized data!
  render json: @posts
end
```

### 2. Use policy_params for Strong Parameters

```ruby
# ✅ Good
def create
  @post = Post.new(policy_params(Post.new))
  authorize @post
  # ...
end

# ❌ Bad
def create
  @post = Post.new(post_params)  # Might allow forbidden attributes
  authorize @post
  # ...
end
```

### 3. Include Permissions in Responses

```ruby
def show
  authorize @post

  render json: {
    data: @post,
    meta: {
      permissions: {
        can_update: policy(@post).update?,
        can_delete: policy(@post).destroy?,
        can_publish: policy(@post).publish?
      }
    }
  }
end
```

### 4. Version Your API

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :posts
  end

  namespace :v2 do
    resources :posts
  end
end

# Different authorization rules per version
module Api
  module V2
    class PostsController < Api::BaseController
      # New authorization logic for v2
    end
  end
end
```

### 5. Document Authorization Requirements

```ruby
# app/controllers/api/v1/posts_controller.rb
class PostsController < ApplicationController
  # @api {get} /api/v1/posts List posts
  # @apiPermission authenticated
  # @apiDescription Returns posts visible to the current user
  #
  # @api {post} /api/v1/posts Create post
  # @apiPermission author
  # @apiDescription Creates a new post. Requires author role.
  #
  # @api {put} /api/v1/posts/:id Update post
  # @apiPermission owner or admin
  # @apiDescription Updates a post. Must be the post owner or an admin.
end
```

## Common Patterns

### Batch Authorization

```ruby
# app/controllers/api/v1/posts_controller.rb
def bulk_update
  posts = Post.where(id: params[:post_ids])

  # Authorize all at once
  authorize_all(posts, :update?)

  posts.each { |post| post.update(policy_params(post)) }

  render json: { updated: posts.count }
rescue SimpleAuthorize::Controller::NotAuthorizedError => e
  render json: { error: "Cannot update all posts" }, status: :forbidden
end
```

### Partial Authorization

```ruby
def bulk_update
  posts = Post.where(id: params[:post_ids])

  # Get only authorized posts
  authorized_posts = authorized_records(posts, :update?)
  unauthorized_count = posts.count - authorized_posts.count

  authorized_posts.each { |post| post.update(policy_params(post)) }

  render json: {
    updated: authorized_posts.count,
    skipped: unauthorized_count
  }
end
```

### Headless Authorization (No Record)

```ruby
# app/controllers/api/v1/dashboard_controller.rb
def show
  authorize_headless(DashboardPolicy, :show?)

  render json: {
    stats: calculate_stats,
    permissions: {
      can_view_analytics: policy(nil).analytics?,
      can_export_data: policy(nil).export?
    }
  }
end
```

### Rate Limiting Based on Authorization

```ruby
class ApplicationController < ActionController::API
  before_action :check_rate_limit

  private

  def check_rate_limit
    limit = if current_user&.admin?
      1000  # Higher limit for admins
    elsif current_user
      100   # Standard limit for users
    else
      10    # Very low limit for guests
    end

    # Implement rate limiting logic
  end
end
```

### Filtering Attributes in Responses

```ruby
def show
  authorize @post

  visible_attrs = visible_attributes(@post)
  filtered_data = @post.attributes.slice(*visible_attrs.map(&:to_s))

  render json: filtered_data
end
```

### Conditional Field Inclusion

```ruby
# app/serializers/user_serializer.rb
class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email

  # Only include email if viewer can see it
  def email
    if policy.attribute_visible?(:email)
      object.email
    else
      nil
    end
  end

  private

  def policy
    @policy ||= UserPolicy.new(scope, object)
  end
end
```

## Testing API Authorization

### Request Specs

```ruby
# spec/requests/api/v1/posts_spec.rb
RSpec.describe "Api::V1::Posts", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{user.api_token}" } }

  describe "GET /api/v1/posts/:id" do
    let(:post) { create(:post) }

    context "when authorized" do
      it "returns the post" do
        get "/api/v1/posts/#{post.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['id']).to eq(post.id)
      end
    end

    context "when not authorized" do
      let(:private_post) { create(:post, :private) }

      it "returns 403" do
        get "/api/v1/posts/#{private_post.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to have_key('error')
      end
    end

    context "when not authenticated" do
      it "returns 401" do
        get "/api/v1/posts/#{post.id}"  # No auth headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/posts" do
    let(:valid_params) { { post: { title: "Test", body: "Content" } } }

    context "as author" do
      let(:author) { create(:user, :author) }
      let(:auth_headers) { { 'Authorization' => "Bearer #{author.api_token}" } }

      it "creates a post" do
        expect {
          post "/api/v1/posts", params: valid_params, headers: auth_headers, as: :json
        }.to change(Post, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "as viewer" do
      it "denies access" do
        post "/api/v1/posts", params: valid_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
```

## Troubleshooting

### Issue: Getting HTML Redirect Instead of JSON Error

**Problem:** API returns HTML redirect instead of JSON error response

**Solution:** Ensure request is properly detected as API request:

```ruby
# Explicitly set format
get '/api/posts/1', headers: { 'Accept' => 'application/json' }

# Or in routes
namespace :api, defaults: { format: :json } do
  resources :posts
end
```

### Issue: 401 vs 403 Confusion

**Problem:** Not sure when to return 401 vs 403

**Solution:**
- `401 Unauthorized`: User is not authenticated (no valid credentials)
- `403 Forbidden`: User is authenticated but lacks permission

SimpleAuthorize handles this automatically based on whether `current_user` is present.

### Issue: CORS Errors

**Problem:** Cross-origin requests are blocked

**Solution:** Configure CORS:

```ruby
# Gemfile
gem 'rack-cors'

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Configure appropriately for production

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

## Conclusion

Key takeaways for API authorization:

1. **Use policy_scope** for all collection endpoints
2. **Return appropriate status codes** (401 vs 403)
3. **Include permissions** in responses for client-side UI
4. **Filter attributes** based on visibility rules
5. **Test thoroughly** with different authentication states
6. **Document requirements** for API consumers
7. **Version your API** for flexibility in authorization changes

SimpleAuthorize makes API authorization straightforward with automatic format detection and appropriate error responses.
