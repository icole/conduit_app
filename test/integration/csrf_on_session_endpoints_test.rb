require "test_helper"

# CON-34: this JSON endpoint runs on the signed-in session but skipped the
# CSRF check, so another site could have saved over a document. SameSite=Lax cookies made that hard,
# but the token is the check that's meant to stop it.
class CsrfOnSessionEndpointsTest < ActionDispatch::IntegrationTest
  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = users(:admin_user)
    get login_path
    post login_path, params: { email: @user.email, password: "password", authenticity_token: page_token }
    assert_equal @user.id, session[:user_id], "signed in"
    @document = Document.create!(title: "Minutes", storage_type: :native)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  def page_token
    css_select("meta[name=csrf-token]").first&.[]("content") || css_select("input[name=authenticity_token]").first["value"]
  end

  def token_from(path)
    get path
    page_token
  end

  test "saving a document's content needs the page's token" do
    patch update_content_document_path(@document), params: { content: "<p>Overwritten</p>" }, as: :json
    assert_response :unprocessable_content
    assert_nil @document.reload.content

    token = token_from(edit_document_path(@document))
    patch update_content_document_path(@document), params: { content: "<p>Saved</p>" }, as: :json,
      headers: { "X-CSRF-Token" => token }
    assert_response :ok
    assert_equal "<p>Saved</p>", @document.reload.content.to_s.strip
  end
end
