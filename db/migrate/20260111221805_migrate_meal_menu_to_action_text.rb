# frozen_string_literal: true

class MigrateMealMenuToActionText < ActiveRecord::Migration[8.1]
  def up
    # Migrate existing menu text to Action Text
    execute <<-SQL.squish
      INSERT INTO action_text_rich_texts (record_type, record_id, name, body, created_at, updated_at)
      SELECT
        'Meal',
        id,
        'menu',
        CONCAT('<p>', REPLACE(REPLACE(menu, E'\\n\\n', '</p><p>'), E'\\n', '<br>'), '</p>'),
        NOW(),
        NOW()
      FROM meals
      WHERE menu IS NOT NULL AND menu != ''
    SQL

    # Keep the old column for now until we verify Action Text works correctly
    # remove_column :meals, :menu
  end

  def down
    # Remove the migrated Action Text records
    ActionText::RichText.where(record_type: "Meal", name: "menu").find_each do |rich_text|
      meal = Meal.find_by(id: rich_text.record_id)
      next unless meal

      # Convert HTML to plain text
      plain_text = rich_text.body.to_plain_text
      meal.update_column(:menu, plain_text)

      rich_text.destroy
    end
  end
end
