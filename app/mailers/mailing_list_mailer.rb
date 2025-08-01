class MailingListMailer < ApplicationMailer
  def forward_email(user, original_mail, mailing_list)
    @user = user
    @mailing_list = mailing_list
    @original_sender = original_mail.from.first
    @original_subject = original_mail.subject

    # Preserve original email content
    @text_content = extract_text_content(original_mail)
    @html_content = extract_html_content(original_mail)

    # Create subject with list prefix, avoiding double prefixing
    subject = build_subject_with_prefix(original_mail.subject, mailing_list.name)

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

  def build_subject_with_prefix(original_subject, list_name)
    # Remove any existing list prefix from the subject
    clean_subject = remove_list_prefix(original_subject, list_name)
    
    # Add the list prefix to the clean subject
    "[#{list_name}] #{clean_subject}"
  end

  def remove_list_prefix(subject, list_name)
    # Remove the list prefix pattern: [listname] at the beginning
    # This handles both "[listname] Subject" and "Re: [listname] Subject" cases
    prefix_pattern = /^\[#{Regexp.escape(list_name)}\]\s*/i
    
    # Also handle cases where Re: comes before the list prefix
    re_prefix_pattern = /^(Re:\s*)?\[#{Regexp.escape(list_name)}\]\s*/i
    
    if subject.match(re_prefix_pattern)
      # If it's a reply with list prefix, keep the "Re:" but remove the list prefix
      subject.gsub(re_prefix_pattern, '\1')
    elsif subject.match(prefix_pattern)
      # If it's just a list prefix, remove it entirely
      subject.gsub(prefix_pattern, '')
    else
      # No list prefix found, return as-is
      subject
    end
  end
end
