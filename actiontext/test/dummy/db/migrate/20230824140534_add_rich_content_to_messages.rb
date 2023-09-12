class AddRichContentToMessages < ActiveRecord::Migration[6.0]
  def change
    change_table :messages do |t|
      t.text :rich_content
    end
  end
end
