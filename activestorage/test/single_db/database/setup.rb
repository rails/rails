# frozen_string_literal: true

require_relative "create_users_migration"
require_relative "create_groups_migration"


ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :replica })
ActiveRecord::Base.connection_pool.migration_context.migrate
ActiveStorageCreateUsers.migrate(:up)
ActiveStorageCreateGroups.migrate(:up)

