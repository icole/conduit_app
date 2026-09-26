require "test_helper"

# Scanners probe for header-based access control by sending Client-IP: 127.0.0.1
# alongside the forwarded chain kamal-proxy sets. Rails' spoofing check used to
# blow up on the contradiction (515 errors in Sentry over three weeks), so we
# drop the header nothing in our stack sets before RemoteIp ever reads it.
class IpSpoofingTest < ActionDispatch::IntegrationTest
  test "a conflicting Client-Ip header does not raise IP spoofing" do
    get "/up", headers: {
      "HTTP_CLIENT_IP" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "45.148.10.123, 172.18.0.3"
    }

    assert_response :success
    assert_equal "45.148.10.123", @request.remote_ip
  end

  test "a Client-Ip header alone cannot set remote_ip" do
    get "/up", headers: { "HTTP_CLIENT_IP" => "45.148.10.123" }

    assert_response :success
    assert_equal "127.0.0.1", @request.remote_ip
  end
end
