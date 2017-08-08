require "fileutils"

namespace :activestorage do
  desc "Copy over the migration needed to the application"
  task :install do
    migration_root = ActiveRecord::Migrator.migrations_paths.first
    migration_file_path = "#{migration_root}/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_active_storage_create_tables.rb"
    FileUtils.mkdir_p Rails.root.join(migration_root)
    FileUtils.cp File.expand_path("../../active_storage/migration.rb", __FILE__), Rails.root.join(migration_file_path)
    puts "Copied migration to #{migration_file_path}"

    puts "Now run rails db:migrate to create the tables for Active Storage"
  end
end
