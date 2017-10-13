# frozen_string_literal: true

require_relative "create_users_migration"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migrator.migrate File.expand_path("../../db/migrate", __dir__)
ActiveStorageCreateUsers.migrate(:up)
