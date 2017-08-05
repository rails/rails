require "active_storage/migration"
require_relative "create_users_migration"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveStorageCreateTables.migrate(:up)
ActiveStorageCreateUsers.migrate(:up)
