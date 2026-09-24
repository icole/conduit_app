# frozen_string_literal: true

# How many people used chat this calendar month, per community and in total,
# against the Stream plan's monthly-active-user allowance.
#
# We count users we issued a Stream token to (User#last_chat_token_at) rather
# than asking Stream, so the guardrail keeps working even if their stats API is
# unavailable. It is a close proxy: the apps fetch a token when chat opens.
class StreamUsageReport
  # Alert bands, highest first.
  THRESHOLDS = [ 90, 70 ].freeze

  def initialize(limit: self.class.plan_limit, now: Time.current)
    @limit = limit.to_i
    @now = now
  end

  # => { total:, by_community: { slug => count }, limit:, percent_used:, threshold:, period: }
  def call
    by_community = {}
    total = 0

    Community.order(:slug).each do |community|
      count = ActsAsTenant.with_tenant(community) { User.where(last_chat_token_at: period).count }
      next if count.zero?

      by_community[community.slug] = count
      total += count
    end

    {
      total: total,
      by_community: by_community,
      limit: @limit,
      percent_used: percent_used(total),
      threshold: threshold(total),
      period: period
    }
  end

  def self.plan_limit
    ENV.fetch("STREAM_MAU_LIMIT", 0).to_i
  end

  private

  def period
    @now.beginning_of_month..@now.end_of_month
  end

  def percent_used(total)
    return nil unless @limit.positive?

    (total * 100.0 / @limit).floor
  end

  def threshold(total)
    used = percent_used(total)
    return nil unless used

    THRESHOLDS.find { |t| used >= t }
  end
end
