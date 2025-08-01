class MailingListMailer < ApplicationMailer
  def forward_email(user, original_mail, mailing_list)
    @user = user
    @mailing_list = mailing_list
    @original_sender = original_mail.from.first
    @original_subject = original_mail.subject

    # Preserve original email content
    @text_content = extract_text_content(original_mail)
    @html_content = extract_html_content(original_mail)

    # Create subject with list prefix
    subject = "[#{mailing_list.name}] #{original_mail.subject}"

    # Forward with list email as sender
    mail(
      to: user.email,
      from: mailing_list.email_address,
      reply_to: mailing_list.email_address,
      subject: subject
    ) do |format|
      format.text { render plain: build_text_content }
      format.html { render "forward_email" }
    end
  end

  def broadcast_email(user, mailing_list, subject, message, sender)
    @user = user
    @mailing_list = mailing_list
    @message = message
    @sender = sender

    mail(
      to: user.email,
      from: mailing_list.email_address,
      reply_to: mailing_list.email_address,
      subject: "[#{mailing_list.name}] #{subject}"
    )
  end

  private

  def extract_text_content(mail)
    if mail.multipart?
      text_part = mail.text_part
      text_part&.body&.decoded || ""
    else
      content_type = mail.content_type || "text/plain"
      # For non-multipart emails, assume it's text content and decode the body
      mail.body.decoded
    end
  end

  def extract_html_content(mail)
    if mail.multipart?
      html_part = mail.html_part
      html_part&.body&.decoded || ""
    else
      content_type = mail.content_type || ""
      content_type.start_with?("text/html") ? mail.body.decoded : ""
    end
  end

  def build_text_content
    content = []
    content << "From: #{@original_sender}"
    content << "Subject: #{@original_subject}"
    content << ""
    content << @text_content
    content << ""
    content << "---"
    content << "You received this message because you are a member of the #{@mailing_list.name} mailing list."
    content << "To reply to this message, send an email to #{@mailing_list.email_address}"

    content.join("\n")
  end
end
