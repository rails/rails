class MigrationVersionCheck < ActiveRecord::Migration.version("4.2")
  def self.up
    raise "incorrect migration version" unless version == 20131219224947
  end

  def self.down
  end
end
