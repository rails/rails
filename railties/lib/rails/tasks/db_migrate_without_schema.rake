namespace :db do
  desc "Run migrations without loading schema.rb"
  task migrate_without_schema: :environment do
    ActiveRecord::Tasks::DatabaseTasks.migrate(skip_initialize: true)
  end
end
