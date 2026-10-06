require "test_helper"

# Buttons, cards, fields and the rest are drawn by our own components
# (app/assets/tailwind/components.css), not a UI kit, so the look is ours to
# change and doesn't shift under us when a dependency upgrades.
class DesignSystemTest < ActionDispatch::IntegrationTest
  test "the stylesheet pages load carries our components and no daisyUI" do
    get login_path
    hrefs = css_select("link[rel=stylesheet]").map { |link| link["href"] }.select { |href| href.start_with?("/assets/tailwind") }
    assert_not_empty hrefs

    css = hrefs.map { |href| get(href) && response.body }.join
    assert_no_match(/daisyUI/i, css)
    assert_match(/\.btn-primary/, css)
    assert_match(/\.modal-box/, css)
  end
end
