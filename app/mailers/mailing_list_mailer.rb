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

    # Generate threading headers for proper conversation grouping
    threading_headers = build_threading_headers(original_mail, mailing_list)

    # Forward with list email as sender
    mail(
      to: user.email,
      from: mailing_list.email_address,
      reply_to: mailing_list.email_address,
      subject: subject,
      **threading_headers
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

    # Generate consistent threading headers for broadcast emails
    thread_id = generate_thread_id(subject, mailing_list)

    mail(
      to: user.email,
      from: mailing_list.email_address,
      reply_to: mailing_list.email_address,
      subject: "[#{mailing_list.name}] #{subject}",
      "References" => thread_id
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
      subject.gsub(prefix_pattern, "")
    else
      # No list prefix found, return as-is
      subject
    end
  end

  def build_threading_headers(original_mail, mailing_list)
    headers = {}

    # Get the original Message-ID or create one for the thread
    original_message_id = original_mail.message_id || original_mail["Message-ID"]&.value

    if original_message_id.present?
      # This is a reply - use In-Reply-To and References headers
      headers["In-Reply-To"] = original_message_id

      # Build References header (chain of all message IDs in the conversation)
      original_references = original_mail["References"]&.value || original_mail.references
      if original_references.present?
        # Add original message ID to existing references
        headers["References"] = "#{original_references} #{original_message_id}".strip
      else
        # Start new reference chain
        headers["References"] = original_message_id
      end
    else
      # New conversation - create a thread identifier based on subject and list
      clean_subject = remove_list_prefix(original_mail.subject, mailing_list.name)
      thread_id = generate_thread_id(clean_subject, mailing_list)
      headers["References"] = thread_id
    end

    headers
  end

  def generate_thread_id(subject, mailing_list)
    # Create a consistent thread ID based on subject and mailing list
    # This ensures all emails with the same subject will thread together
    clean_subject = subject.gsub(/^Re:\s*/i, "").strip.downcase
    thread_seed = "#{mailing_list.name}-#{clean_subject}"
    thread_hash = Digest::SHA256.hexdigest(thread_seed)[0..16]

    "<thread-#{thread_hash}@#{mailing_list.email_address.split('@').last}>"
  end
end
