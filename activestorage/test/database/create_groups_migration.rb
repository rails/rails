# frozen_string_literal: true

class ActiveStorageCreateGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :groups do |t|
    end
  end
end
