class UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    @users = User.all.order(created_at: :desc)
  end

  def edit
  end

  def update
    if update_user
      redirect_to users_path, notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Prevent admins from deleting themselves
    if @user == current_user
      redirect_to users_path, alert: "You cannot delete your own account."
      return
    end

    # Prevent deletion of other admin users
    if @user.admin?
      redirect_to users_path, alert: "Admin users cannot be deleted through this interface."
      return
    end

    @user.destroy
    redirect_to users_path, notice: "User was successfully deleted."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end

  def update_user
    result = @user.update(user_params)

    # Handle admin status separately from mass assignment
    if params[:user] && !params[:user][:admin].nil?
      @user.update(admin: params[:user][:admin] == "1" || params[:user][:admin] == true)
    end

    result
  end
end
