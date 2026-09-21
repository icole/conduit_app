# frozen_string_literal: true

# Creates a community and its founding admin together, for the public
# "start a community" form. The community starts pending with the metered
# features off (see Community#status and FEATURE_FLAGS), so a self-created
# community costs nothing until it is approved.
class CommunitySignup
  attr_reader :community, :user

  def initialize(community_params: {}, user_params: {})
    @community = Community.new(name: community_params[:name].to_s.strip)
    @user = User.new(user_params)
  end

  def save
    assign_generated_attributes
    # The founder belongs to the (still unsaved) community: acts_as_tenant
    # requires the association, and email uniqueness is scoped to it.
    user.community = community
    user.admin = true

    # Validate both halves before writing anything, so the form can show
    # every error at once.
    community_valid = community.valid?
    user_valid = ActsAsTenant.with_tenant(community) { user.valid? }
    return false unless community_valid && user_valid

    ActiveRecord::Base.transaction do
      community.save!
      ActsAsTenant.with_tenant(community) { user.save! }
    end

    user.send_email_verification!
    CommunityMailer.created(community).deliver_later if CommunityMailer.notify_address.present?
    true
  end

  private

  def assign_generated_attributes
    community.slug = self.class.unique_slug(community.name)
    community.domain = "#{community.slug}.#{self.class.domain_suffix}"
    community.status = "pending"
  end

  # "Willow Creek" -> "willow-creek", then -2, -3 ... if taken.
  def self.unique_slug(name)
    base = name.to_s.parameterize.presence || "community"
    return base unless Community.exists?(slug: base)

    suffix = 2
    suffix += 1 while Community.exists?(slug: "#{base}-#{suffix}")
    "#{base}-#{suffix}"
  end

  def self.domain_suffix
    ENV.fetch("CONDUIT_COMMUNITY_DOMAIN_SUFFIX", "conduitcoho.app")
  end
end
