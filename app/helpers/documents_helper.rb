module DocumentsHelper
  # Clean up Google Drive exported HTML by removing the style block but preserving inline formatting
  def clean_google_drive_html(html)
    return "" if html.blank?

    # Parse as full HTML document to properly handle head/body structure
    doc = Nokogiri::HTML(html)

    # Extract just the body content (ignores head with style blocks)
    body = doc.at_css("body")
    return "" unless body

    # Remove any remaining <style> tags that might be in the body
    body.css("style").remove

    # Remove <script> tags
    body.css("script").remove

    # Remove Google's tracking images
    body.css("img[src*='google.com/a/']").remove

    # Remove class attributes (they reference the removed style block)
    # But keep style attributes for inline formatting
    body.traverse do |node|
      if node.element?
        node.remove_attribute("class")
        node.remove_attribute("id")
      end
    end

    # Return the cleaned body HTML
    body.inner_html
  end
end
