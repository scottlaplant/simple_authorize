# Example Posts Controller demonstrating SimpleAuthorize integration
class PostsController < ApplicationController
  include SimpleAuthorize::Controller

  before_action :set_post, only: [:show, :edit, :update, :destroy, :publish]

  def index
    # Use policy_scope to automatically filter posts based on user permissions
    @posts = policy_scope(Post).order(created_at: :desc)
  end

  def show
    # Authorize that the user can view this specific post
    authorize @post

    # Get visible attributes for this user
    @visible_attrs = visible_attributes(@post)

    # Load approved comments (or all if user can moderate)
    @comments = policy_scope(@post.comments)
  end

  def new
    @post = Post.new
    # Authorize that the user can create posts
    authorize @post
  end

  def create
    @post = Post.new
    authorize @post

    # Use policy_params to automatically permit only allowed attributes
    @post.assign_attributes(policy_params(@post))
    @post.user = current_user

    if @post.save
      redirect_to @post, notice: "Post was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @post
    # Get editable attributes for the form
    @editable_attrs = editable_attributes(@post)
  end

  def update
    authorize @post

    if @post.update(policy_params(@post))
      redirect_to @post, notice: "Post was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @post
    @post.destroy
    redirect_to posts_url, notice: "Post was successfully deleted."
  end

  # Custom action: publish a post
  def publish
    # Authorize custom action
    authorize @post, :publish?

    @post.update!(published: true)
    redirect_to @post, notice: "Post published successfully!"
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end
end
