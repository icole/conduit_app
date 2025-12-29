# frozen_string_literal: true

module Api
  module V1
    class CommunitiesController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!
      skip_before_action :set_tenant_from_domain

      # GET /api/v1/communities
      def index
        communities = Community.all.order(:name)
        render json: communities.map { |c|
          {
            id: c.id,
            name: c.name,
            domain: c.domain,
            slug: c.slug
          }
        }
      end
    end
  end
end
