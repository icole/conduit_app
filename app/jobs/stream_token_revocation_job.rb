# frozen_string_literal: true

# Revokes every chat token issued so far to the given users (CON-80), so a
# suspended community's members can't keep using chat with a saved token.
# Tokens issued after this still work, so reinstating the community needs
# nothing more: apps fetch a new token.
class StreamTokenRevocationJob < ApplicationJob
  queue_as :default

  def perform(user_ids, before = Time.current)
    return unless StreamChatClient.configured?

    client = StreamChatClient.client
    user_ids.each do |id|
      client.revoke_user_token(id.to_s, before)
    rescue StandardError => e
      Rails.logger.error "Couldn't revoke Stream tokens for user #{id}: #{e.message}"
    end
  end
end
