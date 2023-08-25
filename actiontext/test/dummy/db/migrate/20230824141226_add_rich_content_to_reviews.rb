class AddRichContentToReviews < ActiveRecord::Migration[6.0]
  def change
    change_table :reviews do |t|
      t.string :rich_content
    end
  end
end
