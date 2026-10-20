# Posts a released task, or a recurring job someone's handing off, to the
# community's coverage chat channel so someone can pick it up. The Available queue stays the source of truth; the message
# just points there.
class CoverageBroadcast
  CHANNEL_NAME = "Chores & Coverage"

  def self.channel_id(community)
    StreamChannelService.community_channel_id(community, community.coverage_chat_channel)
  end

  # Someone can't do a task this time and nobody else is on it
  def self.released(task)
    details = [
      (task.due_date && "due #{task.due_date.strftime('%a %b %-d')}"),
      (task.effort && "#{task.effort.downcase} job")
    ].compact.join(", ")
    by = task.released_by
    new(task.community, by, "#{by&.name&.split&.first} can't do \"#{task.title}\" this time" \
      "#{" (#{details})" if details.present?}. Can you pick it up?")
  end

  # A recurring job's last person is handing it off for good
  def self.handed_off(recurring)
    details = [ recurring.frequency_label.downcase, ("#{recurring.effort.downcase} job" if recurring.effort) ].compact.join(", ")
    by = recurring.handed_off_by
    new(recurring.community, by, "#{by&.name&.split&.first} is handing off \"#{recurring.title}\" (#{details}). Can you take it on?")
  end

  def initialize(community, from, text)
    @community = community
    @from = from
    @text = text
  end

  def deliver
    return unless @from && @community.chat_available? && StreamChatClient.configured?

    client = StreamChatClient.client
    # Members only join the default channels when their app fetches a chat
    # token, so anyone who hasn't opened chat since this channel appeared
    # wouldn't see the post. Everyone in the community gets it.
    members = User.where(community: @community).to_a
    client.upsert_users(members.map(&:stream_user_data))
    channel = client.channel("team", channel_id: self.class.channel_id(@community),
      data: StreamChannelService.channel_data(@community, name: CHANNEL_NAME, created_by_id: @from.id.to_s))
    channel.query(user_id: @from.id.to_s)
    channel.add_members(members.map(&:stream_user_id))
    channel.send_message({ text: message_text }, @from.id.to_s)
  rescue StreamChat::StreamAPIException => e
    Rails.logger.error "[CoverageBroadcast] #{@text}: #{e.message}"
    nil
  end

  private

  def message_text = "#{@text} #{queue_url}"

  def queue_url
    Rails.application.routes.url_helpers.tasks_url(
      host: @community.domain, protocol: Rails.env.production? ? "https" : "http", tab: "available"
    )
  end
end
