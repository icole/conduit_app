class MakeCommentsPolymorphic < ActiveRecord::Migration[8.0]
  def change
    # Add polymorphic columns
    add_column :comments, :commentable_type, :string
    add_column :comments, :commentable_id, :bigint

    # Add index for polymorphic association
    add_index :comments, [ :commentable_type, :commentable_id ]

    # Migrate existing data
    reversible do |dir|
      dir.up do
        # Update existing comments to use polymorphic association
        execute <<-SQL
          UPDATE comments#{' '}
          SET commentable_type = 'Post', commentable_id = post_id#{' '}
          WHERE post_id IS NOT NULL
        SQL
      end
    end

    # Remove the old post_id column (we'll keep it for now to be safe)
    # remove_column :comments, :post_id, :bigint
  end
end
