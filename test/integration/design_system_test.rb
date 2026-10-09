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

  test "the apps wear the website's palette: there's no second theme for them" do
    get login_path, headers: { "User-Agent" => "Conduit iOS/2 (Turbo Native)" }
    assert_select "html[data-theme='conduit-app']"

    css = stylesheet_for(login_path)
    assert_no_match(/cupcake/, css)
  end

  # Headings are Bricolage Grotesque, a sans like the body text, so moving from
  # a heading to the rows under it doesn't switch typeface families
  test "headings are set in Bricolage Grotesque, and pages load it" do
    get login_path
    fonts = css_select("link[href^='https://fonts.googleapis.com']").map { |link| link["href"] }.join
    assert_includes fonts, "family=Bricolage+Grotesque"
    assert_not_includes fonts, "Fraunces"

    css = stylesheet_for(login_path)
    assert_match(/--font-display:\s*"Bricolage Grotesque"/, css)
    assert_no_match(/Fraunces/, css)
  end

  private

  def stylesheet_for(path)
    get path
    href = css_select("link[rel=stylesheet]").map { |link| link["href"] }.find { |h| h.start_with?("/assets/tailwind") }
    get href
    response.body
  end
end
