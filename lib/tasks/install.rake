# frozen_string_literal: true

namespace :action_mailbox do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration"
  task install: %w[ environment run_generator copy_migrations ]

  task :run_generator do
    system "#{RbConfig.ruby} ./bin/rails generate mailbox application"
  end

  task :copy_migrations do
    Rake::Task["active_storage:install:migrations"].invoke
    Rake::Task["railties:install:migrations"].reenable # Otherwise you can't run 2 migration copy tasks in one invocation
    Rake::Task["action_mailbox:install:migrations"].invoke
  end
end
