require "active_vault/migration"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveVault::CreateBlobs.migrate(:up)
