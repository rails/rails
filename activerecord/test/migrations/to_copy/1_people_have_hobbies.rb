class PeopleHaveLastNames < ActiveRecord::Migration
  def self.up
    add_column "people", "hobbies", :text
  end

  def self.down
    remove_column "people", "hobbies"
  end
end
