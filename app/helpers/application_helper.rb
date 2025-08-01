module ApplicationHelper
  include Heroicon::ApplicationHelper
  # Converts a string to title case, keeping small words lowercase
  # Example: "meeting with john and jane at the office" becomes "Meeting with John and Jane at the Office"
  def proper_title_case(text)
    return text unless text.is_a?(String)

    # Words that should remain lowercase in titles (unless they're the first or last word)
    small_words = %w[a an and as at but by en for if in of on or the to v v. via vs vs. with]

    # Split the text into words and capitalize each word unless it's a small word
    result = text.downcase.split.map.with_index do |word, index|
      # Capitalize first word, last word, or non-small words
      if index == 0 || index == text.split.size - 1 || !small_words.include?(word.downcase)
        word.capitalize
      else
        word.downcase
      end
    end

    result.join(" ")
  end

  # Strips HTML tags and attachment filenames from ActionText content for clean previews
  def strip_actiontext_for_preview(rich_text_content)
    return "" if rich_text_content.blank?

    # Convert to string and strip HTML tags
    text = strip_tags(rich_text_content.to_s)

    # Manually handle common HTML entities that CGI.unescapeHTML might miss
    text = text.gsub("&nbsp;", " ")
    text = text.gsub("&amp;", "&")
    text = text.gsub("&lt;", "<")
    text = text.gsub("&gt;", ">")
    text = text.gsub("&quot;", '"')
    text = text.gsub("&#39;", "'")

    # Also try CGI.unescapeHTML for any remaining entities
    text = CGI.unescapeHTML(text)

    # Remove attachment filenames (they appear as standalone text after stripping HTML)
    # This removes common file extensions and patterns that would appear from attachments
    text = text.gsub(/\b[\w\-\.]+\.(jpg|jpeg|png|gif|pdf|doc|docx|txt|csv|xlsx|zip|mp4|mov|avi)\b/i, "")

    # Remove file sizes (e.g., "1.2 MB", "500 KB", "2.5 GB")
    text = text.gsub(/\b\d+(?:\.\d+)?\s*(?:bytes?|kb|mb|gb|tb)\b/i, "")

    # Clean up extra whitespace and normalize spaces
    text.gsub(/\s+/, " ").strip
  end

  # Safely generates a Google Drive link, ensuring URL is valid and safe
  # Returns nil if the URL is invalid or unsafe
  def safe_google_drive_link(document, link_text = "Open in Google Drive", options = {})
    return nil unless document&.safe_google_drive_url

    safe_url = document.safe_google_drive_url
    return nil if safe_url.blank?

    # Additional safety check - ensure URL is properly formatted
    begin
      uri = URI.parse(safe_url)
      return nil unless uri.scheme == "https" && uri.host&.end_with?("google.com")
    rescue URI::InvalidURIError
      return nil
    end

    default_options = { target: "_blank", class: "text-blue-600 hover:text-blue-800 underline" }
    link_to(link_text, safe_url, default_options.merge(options))
  end
end
