# frozen_string_literal: true

# Public "start a community" form. Runs without a tenant (the community does
# not exist yet) and without a session, on the API domain or any host.
class CommunitySignupsController < ApplicationController
  skip_before_action :set_tenant_from_domain
  skip_before_action :authenticate_user!
  skip_before_action :verify_user_belongs_to_tenant!
  skip_before_action :enforce_community_status

  def new
    @signup = CommunitySignup.new
  end

  def create
    @signup = CommunitySignup.new(community_params: community_params, user_params: user_params)

    if @signup.save
      reset_session
      session[:user_id] = @signup.user.id
      session[:community_id] = @signup.community.id
      set_current_tenant(@signup.community)

      redirect_to root_path, notice: "Welcome! #{@signup.community.name} is set up. " \
        "Check your email to verify your address - chat unlocks once your community is approved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def community_params
    params.require(:community).permit(:name)
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
