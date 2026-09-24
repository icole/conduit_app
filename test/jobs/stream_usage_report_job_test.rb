# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class StreamUsageReportJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    ActsAsTenant.without_tenant { User.unscoped.update_all(last_chat_token_at: nil) }
    @users = ActsAsTenant.with_tenant(communities(:crow_woods)) { User.order(:id).limit(10).to_a }

    # The job dedupes alerts through Rails.cache, which is the null store in
    # test; production uses solid_cache, which is durable.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def use_chat(count)
    ids = @users.first(count).map(&:id)
    ActsAsTenant.without_tenant { User.unscoped.where(id: ids).update_all(last_chat_token_at: Time.current) }
  end

  # CONDUIT_ADMIN_EMAIL isn't set in test; alerts need somewhere to go.
  def with_notify_address(&block)
    CommunityMailer.stub(:notify_address, "ops@example.com", &block)
  end

  test "sends no alert below the first threshold" do
    use_chat 1

    with_notify_address do
      assert_no_enqueued_emails do
        StreamUsageReportJob.perform_now(limit: 10)
      end
    end
  end

  test "emails an alert once a threshold is reached" do
    use_chat 7

    with_notify_address do
      assert_enqueued_emails 1 do
        StreamUsageReportJob.perform_now(limit: 10)
      end
    end
  end

  test "does not repeat the same alert on the next run" do
    use_chat 7

    with_notify_address do
      StreamUsageReportJob.perform_now(limit: 10)

      assert_no_enqueued_emails do
        StreamUsageReportJob.perform_now(limit: 10)
      end
    end
  end

  test "alerts again when usage climbs to the next threshold" do
    use_chat 7

    with_notify_address do
      StreamUsageReportJob.perform_now(limit: 10)

      use_chat 9
      assert_enqueued_emails 1 do
        StreamUsageReportJob.perform_now(limit: 10)
      end
    end
  end

  test "sends nothing when no notification address is configured" do
    use_chat 9

    CommunityMailer.stub :notify_address, nil do
      assert_no_enqueued_emails do
        StreamUsageReportJob.perform_now(limit: 10)
      end
    end
  end
end
