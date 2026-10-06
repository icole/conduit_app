require "test_helper"

# Chat's icons are a font that esbuild copies out of stream-chat-react next to
# chat.css. Propshaft publishes every asset under a digested name, so chat.css
# only finds its fonts if Propshaft can resolve and rewrite each url(). An
# absolute url("/assets/...") it can't resolve, so it's left pointing at a file
# that's never published, and the icons 404 in production.
class ChatIconFontsTest < ActiveSupport::TestCase
  test "every file the compiled chat stylesheet points at is a published asset" do
    assets = Rails.application.assets
    chat_css = assets.load_path.find("chat.css")
    skip "no chat.css: run yarn build" unless chat_css

    compiled = assets.compilers.compile(chat_css)
    published = assets.load_path.assets.map { |asset| "/assets/#{asset.digested_path}" }.to_set
    urls = compiled.scan(/url\(\s*["']?([^"')]+)["']?\s*\)/).flatten.reject { |url| url.start_with?("data:") }.map { |url| url.sub(/[#?].*\z/, "") }

    assert_not_empty urls, "chat.css should reference its icon fonts"
    assert_empty urls.uniq.reject { |url| published.include?(url) }, "chat.css points at files that aren't published"
  end
end
