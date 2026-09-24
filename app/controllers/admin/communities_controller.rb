# frozen_string_literal: true

module Admin
  # Cross-community operations for whoever runs the Conduit service: approve a
  # new community, suspend one, and toggle the metered features. Same actions as
  # the communities: rake tasks, reachable from a phone.
  class CommunitiesController < ApplicationController
    before_action :require_super_admin!

    def index
      # Deliberately unscoped: a super admin belongs to one community but
      # administers all of them.
      @communities = Community.order(:status, :name).to_a
      @stats = @communities.index_by(&:id).transform_values { |community| stats_for(community) }
    end

    def approve
      community = find_community
      community.approve! if community.pending?

      redirect_to admin_communities_path, notice: "#{community.name} is now #{community.status}."
    end

    def suspend
      community = find_community
      community.suspend! unless community.suspended?

      redirect_to admin_communities_path, notice: "#{community.name} is suspended and its members are signed out."
    end

    def set_flag
      community = find_community
      flag = params[:flag].to_s

      unless Community::FEATURE_FLAGS.include?(flag)
        redirect_to admin_communities_path, alert: "Unknown feature flag: #{flag}"
        return
      end

      community.public_send("#{flag}=", params[:value])
      community.save!

      redirect_to admin_communities_path,
        notice: "#{community.name}: #{flag.humanize.downcase} is #{community.public_send("#{flag}?") ? 'on' : 'off'}."
    end

    private

    def find_community
      Community.find(params[:id])
    end

    def stats_for(community)
      ActsAsTenant.with_tenant(community) do
        {
          members: User.count,
          chat_users_this_month: User.where(last_chat_token_at: Time.current.all_month).count,
          last_active_at: User.maximum(:last_active_at)
        }
      end
    end

    def require_super_admin!
      return if current_user&.super_admin?

      render plain: "Not authorized", status: :forbidden
    end
  end
end
