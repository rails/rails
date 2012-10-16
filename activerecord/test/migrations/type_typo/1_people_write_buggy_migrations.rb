class PeopleWriteBuggyMigrations < ActiveRecord::Migration
  def self.up
    add_column "people", "type_typos", :bool
  end

  def self.down
    remove_column "people", "type_typos"
  end
end
