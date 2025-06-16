class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_comment, only: [:destroy]

  def create
    @comment = @post.comments.new(comment_params)
    @comment.user = current_user

    respond_to do |format|
      if @comment.save
        format.turbo_stream
        format.html { redirect_back(fallback_location: dashboard_index_path, notice: "Comment added!") }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_comment_#{@post.id}", partial: "comments/form", locals: { post: @post, comment: @comment }) }
        format.html { redirect_back(fallback_location: dashboard_index_path, alert: "Could not add comment: #{@comment.errors.full_messages.join(', ')}") }
      end
    end
  end

  def destroy
    if @comment.user == current_user
      @comment.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back(fallback_location: dashboard_index_path, notice: "Comment deleted!") }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: dashboard_index_path, alert: "You can only delete your own comments.") }
      end
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def set_comment
    @comment = @post.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:content)
  end
end
