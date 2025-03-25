# frozen_string_literal: true

class ActiveStorageCreateGroupsInMain < ActiveRecord::Migration[6.0]
  def change
    create_table :groups do |t|
    end
  end
end