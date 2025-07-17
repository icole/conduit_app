class TopicCommentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_discussion_topic
  before_action :set_topic_comment, only: [ :destroy ]

  def create
    @topic_comment = @discussion_topic.topic_comments.build(topic_comment_params)
    @topic_comment.user = current_user

    if @topic_comment.save
      # Update the discussion topic's last_activity_at timestamp
      @discussion_topic.update(last_activity_at: Time.current)

      respond_to do |format|
        format.turbo_stream {
          @topic_comments = @discussion_topic.topic_comments.top_level.includes(:user, :likes, replies: [ :user, :likes ]).order(created_at: :asc)
          # Create a fresh comment object for the form
          fresh_comment = @discussion_topic.topic_comments.build

          render turbo_stream: [
            turbo_stream.replace("comments", partial: "discussion_topics/comments", locals: { topic_comments: @topic_comments, discussion_topic: @discussion_topic }),
            turbo_stream.replace("comment-form", partial: "discussion_topics/comment_form_section", locals: { discussion_topic: @discussion_topic, topic_comment: fresh_comment })
          ]
        }
        format.html {
          anchor_target = @topic_comment.parent_id.present? ? dom_id(@topic_comment.parent) : dom_id(@topic_comment)
          redirect_to discussion_topic_path(@discussion_topic, anchor: anchor_target)
        }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("comment-form", partial: "discussion_topics/comment_form", locals: { discussion_topic: @discussion_topic, topic_comment: @topic_comment })
        }
        format.html {
          @topic_comments = @discussion_topic.topic_comments.top_level.includes(:user, :likes, replies: [ :user, :likes ]).order(created_at: :asc)
          render "discussion_topics/show", status: :unprocessable_entity
        }
      end
    end
  end

  def destroy
    if @topic_comment.user == current_user || current_user.admin?
      @topic_comment.destroy
      redirect_to @discussion_topic, notice: "Comment was successfully deleted."
    else
      redirect_to @discussion_topic, alert: "You are not authorized to delete this comment."
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
    params.require(:topic_comment).permit(:content, :parent_id)
  end
end
