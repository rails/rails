# frozen_string_literal: true

namespace :active_storage do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration needed to the application"
  task install: :environment do
    if Rake::Task.task_defined?("active_storage:install:migrations")
      Rails::Command.invoke :generate, ["active_storage:install"]
    else
      Rails::Command.invoke :generate, ["active_storage:install", "--within-engine"]
    end
  end

  # desc "Copy over the migrations needed to the application upgrading"
  task update: :environment do
    ENV["MIGRATIONS_PATH"] = "db/update_migrate"

    if Rake::Task.task_defined?("active_storage:install")
      Rails::Command.invoke :generate, ["active_storage:install", "--skip-test-framework"]
    else
      Rails::Command.invoke :generate, ["active_storage:install", "--within-engine", "--skip-test-framework"]
    end
  end
end
