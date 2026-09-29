require "test_helper"

# config/push.yml turns the APNs key back into a PEM. Its line breaks travel
# as \n, and Kamal escapes the backslash on the way into the container.
class PushConfigTest < ActiveSupport::TestCase
  def with_env(vars)
    saved = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end

  test "the APNs key is a readable key whether its line breaks arrive as \\n or Kamal's \\\\n" do
    pem = OpenSSL::PKey::EC.generate("prime256v1").private_to_pem
    { "local" => pem.gsub("\n") { "\\n" }, "through Kamal" => pem.gsub("\n") { "\\\\n" } }.each do |how, escaped|
      with_env("APNS_KEY" => escaped) do
        key = Rails.application.config_for(:push).dig(:apple, :encryption_key)
        assert_equal pem, key, how
        assert_kind_of OpenSSL::PKey::EC, OpenSSL::PKey.read(key), how
      end
    end
  end

  test "the Firebase service account arrives base64-encoded (Kamal would mangle its quotes and backslashes)" do
    account = { "type" => "service_account", "project_id" => "test-project", "private_key" => "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n" }.to_json
    [ Base64.strict_encode64(account), account ].each do |value|
      with_env("FCM_SERVICE_ACCOUNT" => value) do
        assert_equal account, Rails.application.config_for(:push).dig(:google, :encryption_key)
      end
    end
  end
end
