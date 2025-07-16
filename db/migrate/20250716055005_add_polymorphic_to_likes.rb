class AddPolymorphicToLikes < ActiveRecord::Migration[8.0]
  def up
    # Add polymorphic columns
    add_column :likes, :likeable_type, :string
    add_column :likes, :likeable_id, :bigint

    # Populate existing likes with Post data
    execute <<-SQL
      UPDATE likes SET likeable_type = 'Post', likeable_id = post_id;
    SQL

    # Add index for polymorphic association
    add_index :likes, [ :likeable_type, :likeable_id ]

    # Remove old post_id column and index
    remove_index :likes, :post_id
    remove_column :likes, :post_id, :bigint
  end

  def down
    # Add post_id column back
    add_column :likes, :post_id, :bigint

    # Populate post_id from polymorphic data for Posts only
    execute <<-SQL
      UPDATE likes SET post_id = likeable_id WHERE likeable_type = 'Post';
    SQL

    # Delete non-Post likes since we can't convert them back
    execute <<-SQL
      DELETE FROM likes WHERE likeable_type != 'Post';
    SQL

    # Add index back
    add_index :likes, :post_id

    # Remove polymorphic columns
    remove_index :likes, [ :likeable_type, :likeable_id ]
    remove_column :likes, :likeable_type, :string
    remove_column :likes, :likeable_id, :bigint
  end
end
