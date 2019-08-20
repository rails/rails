# frozen_string_literal: true

class ValidWithTimestampsPeopleHaveLastNames < ActiveRecord::Migration::Current
  def self.up
    add_column "people", "last_name", :string
  end

  def self.down
    remove_column "people", "last_name"
  end
end
