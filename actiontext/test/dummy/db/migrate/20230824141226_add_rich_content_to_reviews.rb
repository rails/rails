class AddRichContentToReviews < ActiveRecord::Migration[6.0]
  def change
    change_table :reviews do |t|
      t.text :rich_content
    end
  end
end
