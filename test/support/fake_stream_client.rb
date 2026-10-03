# Stands in for StreamChat::Client in tests: records the tokens minted and
# revoked, and accepts the channel calls made while setting a user up.
class FakeStreamClient
  class Channel
    def query(**) = { "channel" => {} }
    def add_members(*) = true
  end

  attr_reader :tokens, :revoked

  def initialize
    @tokens = []
    @revoked = []
  end

  def upsert_user(*) = {}
  def channel(*, **) = Channel.new

  # Like the real client: a JWT, with an exp claim only when one is given
  def create_token(user_id, exp = nil)
    @tokens << { user_id: user_id, exp: exp }
    "token-for-#{user_id}"
  end

  def revoke_user_token(user_id, before)
    @revoked << { user_id: user_id, before: before }
  end
end
