class PeopleHaveLastNames < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
  def self.up
    add_column "people", "description", :text
  end

  def self.down
    remove_column "people", "description"
  end
end
