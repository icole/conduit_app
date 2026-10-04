require "test_helper"

# The image builds the minified production JavaScript (`yarn build:production`)
# and then precompiles assets. jsbundling-rails makes assets:precompile run the
# development `yarn build` first, which replaced the production bundle: chat.js
# shipped at 4.2 MB with source maps instead of 1.7 MB (CON-74).
class DockerBuildTest < ActiveSupport::TestCase
  test "precompiling assets in the image keeps the production JavaScript build" do
    precompile = Rails.root.join("Dockerfile").readlines.find { |line| line.include?("assets:precompile") }

    assert_includes precompile, "SKIP_JS_BUILD=1"
  end
end
