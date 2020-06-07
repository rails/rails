class CreateReviews < ActiveRecord::Migration[6.0]
  def change
    create_table :reviews do |t|
      t.belongs_to :message, null: false
      t.string :author_name, null: false
    end
  end
end
