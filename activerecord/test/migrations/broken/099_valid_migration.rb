class ValidMigration < ActiveRecord::Migration
  def self.up
    add_column "people", "phone", :string
  end

  def self.down
    remove_column "people", "phone"
  end
end
