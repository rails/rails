class ValidWithTimestampsPeopleHaveLastNames < ActiveRecord::Migration
  def self.up
    add_column "people", "last_name", :string
  end

  def self.down
    remove_column "people", "last_name"
  end
end
