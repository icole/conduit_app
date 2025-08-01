class DiscussionTopicsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_discussion_topic, only: [ :show, :edit, :update, :destroy ]

  def index
    @discussion_topics = DiscussionTopic.includes(:user, :comments)
                                       .by_activity
                                       .limit(15)
  end

  def new
    @discussion_topic = DiscussionTopic.new
  end

  def show
    # Comments are now handled by the shared comments_section partial
  end

  def create
    @discussion_topic = current_user.discussion_topics.build(discussion_topic_params)
    @discussion_topic.last_activity_at = Time.current

    if @discussion_topic.save
      redirect_to @discussion_topic, notice: "Discussion topic was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @discussion_topic.user == current_user
      discussion_topic_with_activity = discussion_topic_params.merge(last_activity_at: Time.current)
      if @discussion_topic.update(discussion_topic_with_activity)
        redirect_to @discussion_topic, notice: "Discussion topic was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @discussion_topic.user == current_user || current_user.admin?
      @discussion_topic.destroy
      redirect_to discussion_topics_path, notice: "Discussion topic was successfully deleted."
    else
      redirect_to discussion_topics_path, alert: "You are not authorized to delete this topic."
    end
  end

  private

  def set_discussion_topic
    @discussion_topic = DiscussionTopic.find(params[:id])
  end

  def discussion_topic_params
    params.require(:discussion_topic).permit(:title, :description)
  end
end
