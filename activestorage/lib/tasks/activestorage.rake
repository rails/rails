# frozen_string_literal: true

namespace :active_storage do
  desc "Copy over the migration needed to the application"
  task install:, [:option] => :environment do
    if Rake::Task.task_defined?("active_storage:install:migrations")
      Rake::Task["active_storage:install:migrations"].invoke(args[:option])
    else
      Rake::Task["app:active_storage:install:migrations"].invoke(args[:option])
    end
  end
end
