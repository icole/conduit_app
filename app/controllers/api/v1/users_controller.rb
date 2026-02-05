module Api
  module V1
    class UsersController < ApplicationController
      # GET /api/v1/users/search?q=
      def search
        query = params[:q].to_s.strip
        if query.blank?
          render json: []
          return
        end

        users = User.where("name ILIKE ?", "%#{sanitize_sql_like(query)}%")
                     .where.not(id: current_user.id)
                     .limit(10)
                     .select(:id, :name, :avatar_url)

        render json: users.map { |u| { id: u.id, name: u.name, avatar_url: u.avatar_url } }
      end

      private

      def sanitize_sql_like(string)
        ActiveRecord::Base.sanitize_sql_like(string)
      end
    end
  end
end
