# frozen_string_literal: true

# Retires a departed member's Stream chat identity after their Conduit
# account is gone (CON-81). Enqueued from account deletion and admin
# removal; async so a Stream outage can never block account deletion.
#
# Deactivation (not deletion) is deliberate: the departed member can no
# longer connect, send, or receive, but their messages stay in shared
# channels for everyone else. Tokens are revoked at the same time so any
# saved token stops working immediately. Reversible with
# StreamChatClient.client.reactivate_user(id); genuine erasure requests
# go through StreamUserAudit#delete_orphans! instead.
class StreamUserRemovalJob < ApplicationJob
  queue_as :default

  def perform(stream_user_id)
    return unless StreamChatClient.configured?

    client = StreamChatClient.client
    attempt(stream_user_id, "deactivate") { client.deactivate_user(stream_user_id) }
    attempt(stream_user_id, "revoke tokens for") { client.revoke_user_token(stream_user_id, Time.current) }
  end

  private

  # Each step runs even if the other fails: either one alone locks the
  # departed user out, and StreamUserAudit's drift report is the backstop.
  def attempt(stream_user_id, action)
    yield
  rescue StandardError => e
    Rails.logger.error("Failed to #{action} Stream user #{stream_user_id}: #{e.message}")
  end
end
