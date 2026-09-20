class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_commentable
  before_action :set_comment, only: [ :destroy ]

  def create
    @comment = Comment.new(comment_params)
    @comment.commentable = @commentable
    @comment.user = current_user

    respond_to do |format|
      if @comment.save
        # Set instance variables for turbo stream templates
        set_legacy_instance_variables
        format.turbo_stream
        format.html { redirect_back(fallback_location: fallback_location, notice: "Comment added!") }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_comment_#{@commentable.class.name.downcase}_#{@commentable.id}", partial: "comments/form", locals: { commentable: @commentable, comment: @comment }) }
        format.html { redirect_back(fallback_location: fallback_location, alert: "Could not add comment: #{@comment.errors.full_messages.join(', ')}") }
      end
    end
  end

  def destroy
    if @comment.user == current_user
      @comment.discard
      respond_to do |format|
        # Set instance variables for turbo stream templates
        set_legacy_instance_variables
        format.turbo_stream
        format.html { redirect_back(fallback_location: fallback_location, notice: "Comment deleted!") }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: fallback_location, alert: "You can only delete your own comments.") }
      end
    end
  end

  private

  def set_commentable
    if params[:meal_id]
      @commentable = Meal.find(params[:meal_id])
    else
      redirect_back(fallback_location: root_path, alert: "Invalid comment target.")
    end
  end

  def set_comment
    @comment = @commentable.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:content, :parent_id)
  end

  def fallback_location
    if @commentable.is_a?(Meal)
      meal_path(@commentable)
    else
      root_path
    end
  end

  def set_legacy_instance_variables
    # Set instance variables for backward compatibility with turbo stream templates
    if @commentable.is_a?(Meal)
      @meal = @commentable
    end
  end
end
