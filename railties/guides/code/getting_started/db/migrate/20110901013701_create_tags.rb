class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do
      string :name
      references :post

      timestamps
    end
    add_index :tags, :post_id
  end
end
