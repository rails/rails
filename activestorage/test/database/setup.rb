# frozen_string_literal: true

require_relative "create_users_migration"
require_relative "create_groups_migration"

# Writing and reading roles are required for the "previewing on the writer DB" test
ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :replica })
ActiveRecord::Base.connection.migration_context.migrate
ActiveStorageCreateUsers.migrate(:up)
ActiveStorageCreateGroups.migrate(:up)
