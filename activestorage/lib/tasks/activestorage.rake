namespace :activestorage do
  desc "Copy over the migration needed to the application"
  task install: :environment do
    Rake::Task["active_storage_engine:install:migrations"].invoke
  end
end
