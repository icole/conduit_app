require "test_helper"

# A password is needed to sign up with email, not with Google or Apple; but
# whoever sets one, it's at least 8 characters (CON-57)
class UserPasswordRulesTest < ActiveSupport::TestCase
  test "Google and Apple members can do without a password" do
    assert User.new(name: "G", email: "g@example.com", provider: "google_oauth2", uid: "g1").valid?
    assert User.new(name: "A", email: "a@example.com", apple_uid: "a1").valid?
    assert_not User.new(name: "E", email: "e@example.com").valid?
  end

  test "anyone setting a password needs at least 8 characters" do
    google = User.create!(name: "G", email: "g@example.com", provider: "google_oauth2", uid: "g1")
    assert_not google.update(password: "short", password_confirmation: "short")

    apple = User.create!(name: "A", email: "a@example.com", apple_uid: "a1")
    assert_not apple.update(password: "short", password_confirmation: "short")
    assert apple.update(password: "long-enough", password_confirmation: "long-enough")
  end
end
