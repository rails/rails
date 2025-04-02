# frozen_string_literal: true

class ActiveStorageCreateUsersInAnimals < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :name
      t.integer :group_id
      t.timestamps
    end
  end
end