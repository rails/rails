# frozen_string_literal: true

namespace :active_storage do
  desc "Copy over the migration needed to the application"
  task install:, [:option] => :environment do |t, args|
    if Rake::Task.task_defined?("active_storage:install:migrations")
      if args[:option] == 'uuid'
        Rake::Task["active_storage:migrate_uuid"]
      else
        Rake::Task["active_storage:install:migrations"]
      end
    else
      if args[:option] == 'uuid'
        Rake::Task["active_storage:migrate_uuid"]
      else
        Rake::Task["app:active_storage:install:migrations"]
      end
    end
  end

  desc "Copy over the migration needed to the application with UUID support"
  task :migrate_uuid, :environment do
    source = File.join(Gem.loaded_specs["rails"].full_gem_path, "activestorage", "db", "migrate_uuid", "20180405125915_create_active_storage_tables.rb")
    target = File.join(Rails.root, "db", "migrate","20180405125915_create_active_storage_tables.rb")
    FileUtils.cp_r source, target
  end
end
