class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do
      string :name
      string :title
      text :content

      timestamps
    end
  end
end
