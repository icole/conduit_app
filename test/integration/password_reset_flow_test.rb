require "test_helper"

# Forgot password, end to end: ask on the community's site, open the emailed
# link, choose a new password, sign in with it
class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = users(:email_user)
    host! "crowwoods.test"
  end

  def reset_link
    mail = ActionMailer::Base.deliveries.last
    assert mail, "a reset email was sent"
    html = (mail.html_part || mail).body.decoded
    URI(Nokogiri::HTML(html).at_css("a[href*='password_reset']")["href"])
  end

  test "a member can reset their password from the emailed link" do
    perform_enqueued_jobs { post password_reset_path, params: { email: @user.email } }

    link = reset_link
    assert_equal "https", link.scheme
    assert_equal "crowwoods.test", link.host

    get "#{link.path}?#{link.query}"
    assert_response :success
    token = css_select("input[name=token]").first["value"]

    patch password_reset_path, params: { token: token, password: "brand-new-pass", password_confirmation: "brand-new-pass" }
    assert_redirected_to login_path

    post login_path, params: { email: @user.email, password: "brand-new-pass" }
    assert_redirected_to root_path
  end

  # The apps' "Forgot password?" opens the shared API domain in the browser,
  # where nobody is signed in, so there's no community to go on but the email
  test "the apps' forgot-password link works, though it opens on the API domain" do
    host! Community.api_domain
    get password_reset_new_path
    assert_select "input[name=email]"

    perform_enqueued_jobs { post password_reset_path, params: { email: @user.email } }
    assert_redirected_to password_reset_new_path
    assert_equal "crowwoods.test", reset_link.host, "the link goes to the member's own community"
  end

  # A self-created community has no domain of its own yet: its links go to the API domain
  test "a reset link opened on the API domain lets the member choose a new password" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)
    host! Community.api_domain

    get password_reset_edit_path(token: token)
    assert_response :success
    patch password_reset_path, params: { token: token, password: "brand-new-pass", password_confirmation: "brand-new-pass" }
    assert_redirected_to login_path
    assert @user.reload.authenticate("brand-new-pass")
  end

  test "the email is matched however it's capitalised or spaced" do
    @user.update_column(:email, "EmailUser@Example.com")
    assert_emails(1) { post password_reset_path, params: { email: " emailuser@EXAMPLE.com " } }
  end

  test "on the API domain an unknown email sends nothing and says the same as ever" do
    host! Community.api_domain
    assert_no_emails { post password_reset_path, params: { email: "nobody@example.com" } }
    assert_redirected_to password_reset_new_path
  end
end
