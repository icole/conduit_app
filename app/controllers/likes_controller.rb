class LikesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post

  def create
    @like = @post.likes.new(user: current_user)

    respond_to do |format|
      if @like.save
        format.turbo_stream
        format.html { redirect_back(fallback_location: dashboard_index_path, notice: "Post liked!") }
      else
        format.html { redirect_back(fallback_location: dashboard_index_path, alert: "Could not like post: #{@like.errors.full_messages.join(', ')}") }
      end
    end
  end

  def destroy
    @like = @post.likes.find_by(user: current_user)

    if @like
      @like.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back(fallback_location: dashboard_index_path, notice: "Post unliked!") }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: dashboard_index_path, alert: "You haven't liked this post.") }
      end
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end
end
