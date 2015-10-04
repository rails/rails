class PeopleHaveLastNames < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
  def self.up
    add_column "people", "hobbies", :text
  end

  def self.down
    remove_column "people", "hobbies"
  end
end
