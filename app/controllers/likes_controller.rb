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
    elsif params[:post_id]
      @likeable = Post.find(params[:post_id])
    elsif params[:topic_comment_id]
      @likeable = TopicComment.find(params[:topic_comment_id])
    elsif params[:discussion_topic_id]
      @likeable = DiscussionTopic.find(params[:discussion_topic_id])
    elsif params[:chore_id]
      @likeable = Chore.find(params[:chore_id])
    else
      redirect_back(fallback_location: root_path, alert: "Invalid like target.")
    end
  end

  def fallback_location
    if @likeable.is_a?(Post)
      dashboard_index_path
    elsif @likeable.is_a?(DiscussionTopic)
      @likeable
    elsif @likeable.is_a?(TopicComment)
      @likeable.discussion_topic
    elsif @likeable.is_a?(Comment)
      if @likeable.commentable.is_a?(Chore)
        @likeable.commentable
      elsif @likeable.commentable.is_a?(Post)
        dashboard_index_path
      else
        root_path
      end
    elsif @likeable.is_a?(Chore)
      chores_path(view: "proposed")
    else
      root_path
    end
  end
end
