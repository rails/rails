# frozen_string_literal: true

class ActiveStorageCreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :name
      t.integer :group_id
      t.integer :lock_version, null: false, default: 0
      t.string :type
      t.timestamps
    end
  end
end
