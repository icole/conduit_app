require "test_helper"

# The Android release app only speaks HTTPS. Plain HTTP to the emulator's host
# is a debug-build allowance: src/debug overrides the config in src/main,
# which is the one release builds get.
class AndroidNetworkSecurityTest < ActiveSupport::TestCase
  RES = Rails.root.join("android/app/src")
  RELEASE = RES.join("main/res/xml/network_security_config.xml")
  DEBUG = RES.join("debug/res/xml/network_security_config.xml")

  test "release builds allow no plain HTTP to any host" do
    config = RELEASE.read
    assert_no_match(/cleartextTrafficPermitted="true"/, config)
    assert_match(/<base-config cleartextTrafficPermitted="false"/, config)
    assert_no_match(/192\.168\.|10\.0\.2\.2|localhost/, config)
  end

  test "debug builds can reach a dev server on the emulator's host over plain HTTP" do
    config = DEBUG.read
    allowed = config[%r{<domain-config cleartextTrafficPermitted="true">(.*?)</domain-config>}m, 1]
    assert allowed, "the debug config should allow cleartext for the dev server"
    assert_includes allowed, "10.0.2.2"
    assert_includes allowed, "localhost"
    assert_no_match(/192\.168\./, config)
    assert_match(/<base-config cleartextTrafficPermitted="false"/, config)
  end
end
