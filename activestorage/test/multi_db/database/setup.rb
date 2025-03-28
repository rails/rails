# frozen_string_literal: true

require_relative "create_users_in_main"
require_relative "create_groups_in_main"
require_relative "create_users_in_animals"
require_relative "create_groups_in_animals"

mapped_versions = ActiveRecord::Tasks::DatabaseTasks.db_configs_with_versions

mapped_versions.sort.each do |version, db_configs|
  db_configs.each do |db_config|
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(db_config) do
      ActiveRecord::Tasks::DatabaseTasks.migrate(version)
    end
  end
end

main_connection = MainRecord.connection
animals_connection = AnimalsRecord.connection

ActiveStorageCreateUsersInMain.new.exec_migration(main_connection, :up) unless main_connection.table_exists?(:users)
ActiveStorageCreateGroupsInMain.new.exec_migration(main_connection, :up) unless main_connection.table_exists?(:groups)

ActiveStorageCreateUsersInAnimals.new.exec_migration(animals_connection, :up) unless animals_connection.table_exists?(:users)
ActiveStorageCreateGroupsInAnimals.new.exec_migration(animals_connection, :up) unless animals_connection.table_exists?(:groups)
