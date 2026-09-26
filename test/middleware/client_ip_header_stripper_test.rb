require "test_helper"

class ClientIpHeaderStripperTest < ActiveSupport::TestCase
  test "removes the Client-Ip header before the app sees it" do
    seen = nil
    middleware = ClientIpHeaderStripper.new(->(env) { seen = env; [ 200, {}, [ "OK" ] ] })

    middleware.call("HTTP_CLIENT_IP" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "45.148.10.123")

    assert_nil seen["HTTP_CLIENT_IP"]
    assert_equal "45.148.10.123", seen["HTTP_X_FORWARDED_FOR"]
  end

  test "leaves requests without the header alone" do
    seen = nil
    middleware = ClientIpHeaderStripper.new(->(env) { seen = env; [ 200, {}, [ "OK" ] ] })

    status, _, body = middleware.call("HTTP_X_FORWARDED_FOR" => "45.148.10.123")

    assert_equal 200, status
    assert_equal [ "OK" ], body
    assert_equal "45.148.10.123", seen["HTTP_X_FORWARDED_FOR"]
  end
end
