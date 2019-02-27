class AddColumnsToMessage < ActiveRecord::Migration[6.0]
  def change
    add_column :messages, :content, :string
    add_column :messages, :body, :string
  end
end
