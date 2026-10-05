require "test_helper"

# Tests never reach the network. The demo seeding posted to the development
# Stream app on every run (.env's keys load in test) and failed when it timed
# out; any call like that now fails at once and names the request.
class NetworkGuardTest < ActiveSupport::TestCase
  test "a real request from a test is refused" do
    assert_raises(WebMock::NetConnectNotAllowedError) do
      Net::HTTP.get(URI("https://chat.stream-io-api.com/"))
    end
  end
end
