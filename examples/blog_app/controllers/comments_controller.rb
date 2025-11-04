# Example Comments Controller demonstrating SimpleAuthorize integration
class CommentsController < ApplicationController
  include SimpleAuthorize::Controller

  before_action :set_post
  before_action :set_comment, only: [:show, :edit, :update, :destroy, :approve]

  def index
    # Show all approved comments (or all if user can moderate)
    @comments = policy_scope(@post.comments).order(created_at: :desc)
  end

  def show
    authorize @comment
  end

  def new
    @comment = @post.comments.new
    authorize @comment
  end

  def create
    @comment = @post.comments.new
    authorize @comment

    @comment.assign_attributes(policy_params(@comment))
    @comment.user = current_user

    if @comment.save
      redirect_to [@post, @comment], notice: "Comment was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @comment
  end

  def update
    authorize @comment

    if @comment.update(policy_params(@comment))
      redirect_to [@post, @comment], notice: "Comment was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @comment
    @comment.destroy
    redirect_to post_comments_url(@post), notice: "Comment was successfully deleted."
  end

  # Custom action: approve a comment
  def approve
    authorize @comment, :approve?

    @comment.update!(approved: true)
    redirect_to [@post, @comment], notice: "Comment approved!"
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def set_comment
    @comment = @post.comments.find(params[:id])
  end
end
