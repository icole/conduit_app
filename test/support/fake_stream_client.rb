# Stands in for StreamChat::Client in tests: records the tokens minted and
# revoked and the channels cleared and posted to, and accepts the channel
# calls made while setting a user up.
class FakeStreamClient
  class Channel
    def initialize(client, cid)
      @client = client
      @cid = cid
    end

    def query(**) = { "channel" => {} }
    def add_members(*) = true
    def truncate(**) = @client.truncated << @cid
    def send_message(message, user_id, **) = @client.messages << { channel: @cid, user_id: user_id, text: message[:text] }
  end

  attr_reader :tokens, :revoked, :truncated, :messages

  def initialize
    @tokens = []
    @revoked = []
    @truncated = []
    @messages = []
  end

  def upsert_user(*) = {}
  def upsert_users(*) = {}
  def channel(type, channel_id: nil, **) = Channel.new(self, "#{type}:#{channel_id}")

  # Like the real client: a JWT, with an exp claim only when one is given
  def create_token(user_id, exp = nil)
    @tokens << { user_id: user_id, exp: exp }
    "token-for-#{user_id}"
  end

  def revoke_user_token(user_id, before)
    @revoked << { user_id: user_id, before: before }
  end
end
