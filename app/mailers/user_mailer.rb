# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = password_reset_edit_url(token: @token)

    mail(to: @user.email, subject: "Reset your password")
  end

  def verify_email(user, token)
    @user = user
    @verify_url = verify_email_url(token)

    mail(to: @user.email, subject: "Verify your email address for Conduit")
  end
end
