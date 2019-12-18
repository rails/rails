# frozen_string_literal: true

namespace :active_storage do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration needed to the application"
  task install: :environment do
    if Rake::Task.task_defined?("active_storage:install:migrations")
      Rake::Task["active_storage:install:migrations"].invoke
    else
      Rake::Task["app:active_storage:install:migrations"].invoke
    end
  end

  # desc "Copy over the migrations needed to the application upgrading"
  task update: :environment do
    ENV["MIGRATIONS_PATH"] = "db/update_migrate"

    Rake::Task["active_storage:install"].invoke
  end
end
