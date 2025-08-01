require "test_helper"

class MailingListMailboxTest < ActionMailbox::TestCase
  include ActionMailer::TestHelper
  setup do
    @mailing_list = MailingList.create!(name: "test-list", description: "Test list")
    @user1 = User.create!(name: "User 1", email: "user1@example.com", password: "password123")
    @user2 = User.create!(name: "User 2", email: "user2@example.com", password: "password123")
    @mailing_list.add_user(@user1)
    @mailing_list.add_user(@user2)

    # Set domain for testing
    ENV["MAILING_LIST_DOMAIN"] = "test.com"
    ENV["MAILING_LIST_SUBDOMAIN"] = "lists"
  end

  test "forwards email to mailing list members" do
    email = create_inbound_email_from_mail(
      from: "sender@example.com",
      to: "test-list@lists.test.com",
      subject: "Test subject",
      body: "Test message body"
    )

    assert_emails 2 do
      email.route
    end
  end

  test "ignores email for unknown mailing list" do
    email = create_inbound_email_from_mail(
      from: "sender@example.com",
      to: "unknown-list@lists.test.com",
      subject: "Test subject",
      body: "Test message body"
    )

    assert_no_emails do
      email.route
    end
  end

  test "ignores email for inactive mailing list" do
    @mailing_list.update!(active: false)

    email = create_inbound_email_from_mail(
      from: "sender@example.com",
      to: "test-list@lists.test.com",
      subject: "Test subject",
      body: "Test message body"
    )

    assert_no_emails do
      email.route
    end
  end
end
