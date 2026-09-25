# Posts a released task to the community's coverage chat channel so someone
# can pick it up. The Available queue stays the source of truth; the message
# just points there.
class CoverageBroadcast
  CHANNEL_NAME = "Chores & Coverage"

  def self.channel_id(community)
    StreamChannelService.community_channel_id(community, community.coverage_chat_channel)
  end

  def initialize(task)
    @task = task
    @community = task.community
    @releaser = task.released_by
  end

  def deliver
    return unless @releaser && @community.chat_available? && StreamChatClient.configured?

    client = StreamChatClient.client
    client.upsert_user(@releaser.stream_user_data)
    channel = client.channel("team", channel_id: self.class.channel_id(@community),
      data: StreamChannelService.channel_data(@community, name: CHANNEL_NAME, created_by_id: @releaser.id.to_s))
    channel.query(user_id: @releaser.id.to_s)
    channel.send_message({ text: message_text }, @releaser.id.to_s)
  rescue StreamChat::StreamAPIException => e
    Rails.logger.error "[CoverageBroadcast] Task #{@task.id}: #{e.message}"
    nil
  end

  private

  def message_text
    details = [
      (@task.due_date && "due #{@task.due_date.strftime('%a %b %-d')}"),
      RecurringTask.effort_label(@task.estimated_minutes)
    ].compact.join(", ")

    "#{@releaser.name.split.first} can't do \"#{@task.title}\" this time" \
      "#{" (#{details})" if details.present?}. Can you pick it up? #{queue_url}"
  end

  def queue_url
    Rails.application.routes.url_helpers.tasks_url(
      host: @community.domain, protocol: Rails.env.production? ? "https" : "http", tab: "available"
    )
  end
end
