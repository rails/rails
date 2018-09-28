# frozen_string_literal: true

namespace :action_mailbox do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration"
  task install: %w( environment copy_migration active_storage:install )

  task :copy_migration do
    if Rake::Task.task_defined?("action_mailbox:install:migrations")
      Rake::Task["action_mailbox:install:migrations"].invoke
    else
      Rake::Task["app:action_mailbox:install:migrations"].invoke
    end
  end
end
