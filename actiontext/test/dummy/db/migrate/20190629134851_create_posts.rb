class CreatePosts < ActiveRecord::Migration[6.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :custom_body, size: :long
      t.timestamps
    end
  end
end
