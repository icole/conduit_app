# frozen_string_literal: true

module Api
  module V1
    class CommunitiesController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!
      skip_before_action :set_tenant_from_domain

      # GET /api/v1/communities/lookup?slug=willow-creek
      # Finds one community by slug or domain so a member can reach it without
      # the app listing every community. Pending communities are findable -
      # their founder has to be able to sign in - but suspended ones are not.
      def lookup
        query = params[:slug].to_s.strip.downcase
        if query.blank?
          render json: { error: "slug_required" }, status: :bad_request
          return
        end

        community = Community.where.not(status: "suspended")
                             .where("LOWER(slug) = :q OR LOWER(domain) = :q", q: query)
                             .first

        if community
          render json: community_json(community)
        else
          render json: { error: "community_not_found" }, status: :not_found
        end
      end

      # GET /api/v1/communities
      def index
        render json: Community.active.order(:name).map { |c| community_json(c) }
      end

      private

      def community_json(community)
        {
          id: community.id,
          name: community.name,
          domain: community.domain,
          slug: community.slug,
          status: community.status
        }
      end
    end
  end
end
