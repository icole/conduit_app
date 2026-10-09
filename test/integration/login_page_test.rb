require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  # The login page's big panel names the community you're signing in to
  test "the login page is headed with the community whose domain you're on" do
    host! "crowwoods.test"
    get login_path
    assert_select "section h1", text: "Crow Woods."

    host! "other.test"
    get login_path
    assert_select "section h1", text: "Other Community."
    assert_no_match(/Supper at six/, response.body)
  end
end
