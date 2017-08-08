require "fileutils"

namespace :activestorage do
  desc "Copy over the migration needed to the application"
  task install: :environment do
    migration_root = Rails.root.join(ActiveRecord::Migrator.migrations_paths.first)
    FileUtils.mkdir_p(migration_root)

    migration_class_name = "ActiveStorageCreateTables"
    migrations = ActiveRecord::Migrator.migrations(migration_root)

    if migrations.detect { |migration| migration.name == migration_class_name }
      puts "Migration #{migration_class_name} already exists"
    else
      next_migration_version = ActiveRecord::Migration.next_migration_number(migrations.empty? ? 0 : migrations.last.version + 1).to_i
      migration_file = migration_root.join("#{next_migration_version}_active_storage_create_tables.rb")

      FileUtils.cp File.expand_path("../active_storage/migration.rb", __dir__), migration_file
      puts "Copied migration to #{migration_file.relative_path_from(Rails.root)}"

      puts "Run `rails db:migrate` to create the tables for Active Storage"
    end
  end
end
