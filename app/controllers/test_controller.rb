class TestController < ApplicationController
  skip_before_action :authenticate_user!, if: -> { defined?(authenticate_user!) }

  def env_test
    @client_id = ENV["GOOGLE_CLIENT_ID"]
    @client_secret = ENV["GOOGLE_CLIENT_SECRET"]
    render plain: "GOOGLE_CLIENT_ID: #{@client_id}\nGOOGLE_CLIENT_SECRET: #{@client_secret}"
  end
end
