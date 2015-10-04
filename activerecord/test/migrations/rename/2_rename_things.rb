class RenameThings < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
  def self.up
    rename_table "things", "awesome_things"
  end

  def self.down
    rename_table "awesome_things", "things"
  end
end
