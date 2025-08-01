require "test_helper"

class MailingListMailerTest < ActionMailer::TestCase
  setup do
    @mailing_list = MailingList.create!(name: "test-list", description: "Test list")
    @user = User.create!(name: "Test User", email: "user@example.com", password: "password123")
    @sender = User.create!(name: "Sender", email: "sender@example.com", password: "password123")
  end

  test "broadcast_email" do
    email = MailingListMailer.broadcast_email(@user, @mailing_list, "Test Subject", "Test message", @sender)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email ], email.to
    assert_equal @mailing_list.email_address, email.from.first
    assert_equal @mailing_list.email_address, email.reply_to.first
    assert_equal "[test-list] Test Subject", email.subject
    assert_match "Test message", email.body.to_s
  end

  test "forward_email preserves original content" do
    # Create a mock original email
    original_mail = Mail.new do
      from "original@example.com"
      to "test-list@lists.test.com"
      subject "Original Subject"
      body "Original message content"
    end

    email = MailingListMailer.forward_email(@user, original_mail, @mailing_list)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email ], email.to
    assert_equal @mailing_list.email_address, email.from.first
    assert_equal "[test-list] Original Subject", email.subject

    # Check HTML part contains the original content
    html_part = email.html_part
    assert html_part, "Email should have HTML part"
    assert_match "Original message content", html_part.body.to_s
    assert_match "original@example.com", html_part.body.to_s

    # Check text part contains the original content
    text_part = email.text_part
    assert text_part, "Email should have text part"
    assert_match "Original message content", text_part.body.to_s
    assert_match "original@example.com", text_part.body.to_s
  end
end
