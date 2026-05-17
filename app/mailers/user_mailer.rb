# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = password_reset_edit_url(token: @token)

    mail(to: @user.email, subject: "Reset your password")
  end
end
