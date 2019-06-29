class CreateComments < ActiveRecord::Migration[6.0]
  def change
    create_table :comments do |t|
      t.belongs_to :post, null: false
      t.string :author_name, null: false
      t.text :comment_contents, size: :long
    end
  end
end
