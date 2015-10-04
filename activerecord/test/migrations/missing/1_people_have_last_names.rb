class PeopleHaveLastNames < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
  def self.up
    add_column "people", "last_name", :string
  end

  def self.down
    remove_column "people", "last_name"
  end
end
