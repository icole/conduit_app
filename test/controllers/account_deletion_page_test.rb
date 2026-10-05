require "test_helper"

# Google Play needs a public web page explaining how to delete an account
# (CON-65). It works signed out, on any of our addresses.
class AccountDeletionPageTest < ActionDispatch::IntegrationTest
  test "anyone can read how to delete their account" do
    host! "api.conduitcoho.app"
    get delete_account_info_path

    assert_response :success
    assert_select "h1", text: /Deleting your Conduit account/
    assert_match "Account", response.body
    assert_match "ian@colecoding.com", response.body
  end
end
