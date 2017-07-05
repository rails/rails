require "active_vault/migration"
require_relative "create_users_migration"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveVault::CreateTables.migrate(:up)
ActiveVault::CreateUsers.migrate(:up)
