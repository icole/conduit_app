# frozen_string_literal: true

class AutoLinkUrlsInMealMenus < ActiveRecord::Migration[8.1]
  URL_REGEX = %r{(?<!")https?://[^\s<>"]+}

  def up
    ActionText::RichText.where(record_type: "Meal", name: "menu").find_each do |rich_text|
      original_body = rich_text.body.to_s
      next unless original_body.match?(URL_REGEX)

      # Convert plain text URLs to anchor tags
      updated_body = original_body.gsub(URL_REGEX) do |url|
        %(<a href="#{url}">#{url}</a>)
      end

      # Only update if changed
      if updated_body != original_body
        rich_text.update_column(:body, updated_body)
        Rails.logger.info "Auto-linked URLs in Meal menu #{rich_text.record_id}"
      end
    end
  end

  def down
    # No-op: can't reliably reverse auto-linking
  end
end
