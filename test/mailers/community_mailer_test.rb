# frozen_string_literal: true

require "test_helper"

class CommunityMailerTest < ActionMailer::TestCase
  test "approved goes to the community's admins" do
    community = communities(:pending_community)

    email = CommunityMailer.approved(community)

    assert_equal [ users(:pending_admin).email ], email.to
    assert_match(/approved/i, email.subject)
    assert_match(/Pending Community/, email.body.encoded)
  end

  test "approve! enqueues the approval email" do
    assert_enqueued_emails 1 do
      communities(:pending_community).approve!
    end
  end
end
