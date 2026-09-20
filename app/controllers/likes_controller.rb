class LikesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_likeable

  def create
    @like = @likeable.likes.new(user: current_user)

    respond_to do |format|
      if @like.save
        format.turbo_stream { render :toggle }
        format.html { redirect_back(fallback_location: fallback_location, notice: "#{@likeable.class.name} liked!") }
      else
        format.html { redirect_back(fallback_location: fallback_location, alert: "Could not like #{@likeable.class.name.downcase}: #{@like.errors.full_messages.join(', ')}") }
      end
    end
  end

  def destroy
    @like = @likeable.likes.find_by(user: current_user)

    if @like
      @like.destroy
      respond_to do |format|
        format.turbo_stream { render :toggle }
        format.html { redirect_back(fallback_location: fallback_location, notice: "#{@likeable.class.name} unliked!") }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: fallback_location, alert: "You haven't liked this #{@likeable.class.name.downcase}.") }
      end
    end
  end

  private

  def set_likeable
    if params[:comment_id]
      @likeable = Comment.find(params[:comment_id])
    else
      redirect_back(fallback_location: root_path, alert: "Invalid like target.")
    end
  end

  def fallback_location
    if @likeable.is_a?(Comment) && @likeable.commentable.is_a?(Meal)
      meal_path(@likeable.commentable)
    else
      root_path
    end
  end
end
