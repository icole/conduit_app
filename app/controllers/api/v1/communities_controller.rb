# frozen_string_literal: true

module Api
  module V1
    class CommunitiesController < ApplicationController
      # The apps' community picker runs before anyone signs in, on the API
      # domain. Read-only, and it answers one exact name, never a list.
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!
      skip_before_action :set_tenant_from_domain

      # GET /api/v1/communities/lookup?slug=willow-creek
      # Finds one community by slug or domain so a member can reach it without
      # the app listing every community. Pending communities are findable -
      # their founder has to be able to sign in - but suspended ones are not.
      # What people type on the apps' "Find Your Community" screen: the
      # community's name as they know it ("Crow Woods"), its slug
      # ("crow-woods"), or its domain. Exact matches only (ignoring capitals
      # and extra spaces), so it never lists or hints at other communities.
      def lookup
        query = params[:slug].to_s.squish.downcase
        if query.blank?
          render json: { error: "slug_required" }, status: :bad_request
          return
        end

        community = Community.where.not(status: "suspended")
                             .where("LOWER(slug) IN (:q, :slug) OR LOWER(domain) = :q OR LOWER(REGEXP_REPLACE(TRIM(name), '\\s+', ' ', 'g')) = :q",
                                    q: query, slug: query.parameterize)
                             .first

        if community
          render json: community_json(community)
        else
          render json: { error: "community_not_found" }, status: :not_found
        end
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
