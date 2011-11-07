class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do
      string :commenter
      text :body
      references :post

      timestamps
    end
    add_index :comments, :post_id
  end
end
