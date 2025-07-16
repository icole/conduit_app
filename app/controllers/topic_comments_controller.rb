class TopicCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_discussion_topic
  before_action :set_topic_comment, only: [:destroy]

  def create
    @topic_comment = @discussion_topic.topic_comments.build(topic_comment_params)
    @topic_comment.user = current_user

    if @topic_comment.save
      # Update the discussion topic's last_activity_at timestamp
      @discussion_topic.update(last_activity_at: Time.current)
      redirect_to @discussion_topic, notice: 'Comment was successfully added.'
    else
      @topic_comments = @discussion_topic.topic_comments.includes(:user, :likes).order(created_at: :asc)
      render 'discussion_topics/show', status: :unprocessable_entity
    end
  end

  def destroy
    if @topic_comment.user == current_user || current_user.admin?
      @topic_comment.destroy
      redirect_to @discussion_topic, notice: 'Comment was successfully deleted.'
    else
      redirect_to @discussion_topic, alert: 'You are not authorized to delete this comment.'
    end
  end

  private

  def set_discussion_topic
    @discussion_topic = DiscussionTopic.find(params[:discussion_topic_id])
  end

  def set_topic_comment
    @topic_comment = @discussion_topic.topic_comments.find(params[:id])
  end

  def topic_comment_params
    params.require(:topic_comment).permit(:content)
  end
end
