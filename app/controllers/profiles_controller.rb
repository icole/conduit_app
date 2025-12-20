class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def edit
    # Edit form for current user's profile
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update
    if @user.update(user_params)
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "user_name_edit",
            partial: "profiles/name_display",
            locals: { user: @user }
          )
        }
        format.html { redirect_to account_path, notice: "Your profile has been updated successfully." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:name)
  end
end
