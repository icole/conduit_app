class MailingListsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_mailing_list, only: [ :show, :edit, :update, :destroy, :add_member, :remove_member, :broadcast, :send_broadcast ]

  def index
    @mailing_lists = MailingList.active.includes(:users)
  end

  def show
    @users = User.all.order(:name)
    @members = @mailing_list.users.order(:name)
    @non_members = @users - @members
  end

  def new
    @mailing_list = MailingList.new
  end

  def create
    @mailing_list = MailingList.new(mailing_list_params)

    if @mailing_list.save
      redirect_to @mailing_list, notice: "Mailing list was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @mailing_list.update(mailing_list_params)
      redirect_to @mailing_list, notice: "Mailing list was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mailing_list.destroy!
    redirect_to mailing_lists_path, notice: "Mailing list was successfully deleted."
  end

  def add_member
    user = User.find(params[:user_id])

    if @mailing_list.add_user(user)
      redirect_to @mailing_list, notice: "#{user.name} has been added to #{@mailing_list.name}."
    else
      redirect_to @mailing_list, alert: "Failed to add #{user.name} to the mailing list."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to @mailing_list, alert: "User not found."
  end

  def remove_member
    user = User.find(params[:user_id])

    if @mailing_list.remove_user(user)
      redirect_to @mailing_list, notice: "#{user.name} has been removed from #{@mailing_list.name}."
    else
      redirect_to @mailing_list, alert: "Failed to remove #{user.name} from the mailing list."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to @mailing_list, alert: "User not found."
  end

  def broadcast
    # Show broadcast form
  end

  def send_broadcast
    subject = params[:subject]
    message = params[:message]

    if subject.blank? || message.blank?
      flash[:alert] = "Subject and message are required."
      render :broadcast, status: :unprocessable_entity
      return
    end

    # Send email via Mailgun mailing list
    if @mailing_list.send_message(current_user.name, subject, message)
      redirect_to @mailing_list, notice: "Email sent to #{@mailing_list.users.count} members via Mailgun."
    else
      flash[:alert] = "Failed to send email. Please check the logs for details."
      render :broadcast, status: :unprocessable_entity
    end
  end

  private

  def set_mailing_list
    @mailing_list = MailingList.find(params[:id])
  end

  def mailing_list_params
    params.require(:mailing_list).permit(:name, :description, :active)
  end
end
