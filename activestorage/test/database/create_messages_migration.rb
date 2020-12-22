# frozen_string_literal: true

class ActiveStorageCreateMessages < ActiveRecord::Migration[6.2]
  def change
    create_table :messages, primary_key: :integer_id do |t|
      t.text :body

      t.timestamps
    end
  end
end
