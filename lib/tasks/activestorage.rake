require "fileutils"

namespace :activestorage do
  desc "Copy over the migration needed to the application"
  task :migration do
    FileUtils.cp \
      File.expand_path("../../active_storage/migration.rb", __FILE__),
      Rails.root.join("db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_active_storage_create_tables.rb")

    puts "Now run rails db:migrate to create the tables for Active Storage"
  end
end
