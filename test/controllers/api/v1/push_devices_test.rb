require "test_helper"

# The apps register their notification token here so the server can send
# them push notifications (task reminders).
class Api::V1::PushDevicesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  def auth(user = @user)
    { "Authorization" => "Bearer #{JwtService.generate_auth_token(user)}" }
  end

  test "an app registers its token for the signed-in person" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple", name: "iPhone" }, headers: auth
    assert_response :created

    device = ApplicationPushDevice.find_by!(token: "abc123")
    assert_equal [ @user, "apple", "iPhone" ], [ device.owner, device.platform, device.name ]
  end

  test "registering the same token again doesn't make a second device" do
    2.times { post "/api/v1/push_devices", params: { token: "abc123", platform: "google" }, headers: auth }
    assert_equal 1, ApplicationPushDevice.where(token: "abc123").count
  end

  test "a phone that changes hands goes to whoever signed in last" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple" }, headers: auth
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple" }, headers: auth(users(:two))
    assert_equal users(:two), ApplicationPushDevice.find_by!(token: "abc123").owner
  end

  test "signing out on a phone removes its token" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple" }, headers: auth
    delete "/api/v1/push_devices", params: { token: "abc123" }, headers: auth
    assert_response :no_content
    assert_not ApplicationPushDevice.exists?(token: "abc123")
  end

  test "you can't remove someone else's device" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple" }, headers: auth
    delete "/api/v1/push_devices", params: { token: "abc123" }, headers: auth(users(:two))
    assert ApplicationPushDevice.exists?(token: "abc123")
  end

  test "an unknown platform is refused" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "windows" }, headers: auth
    assert_response :unprocessable_entity
  end

  test "it needs the app's sign-in token" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple" }
    assert_response :unauthorized
    assert_not ApplicationPushDevice.exists?(token: "abc123")
  end

  test "deleting an account removes its devices" do
    post "/api/v1/push_devices", params: { token: "abc123", platform: "apple" }, headers: auth(users(:four))
    users(:four).destroy!
    assert_not ApplicationPushDevice.exists?(token: "abc123")
  end
end
