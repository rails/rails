# frozen_string_literal: true

namespace :action_mailbox do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration and fixtures"
  task install: %w( environment active_storage:install copy_migration copy_fixtures )

  task :copy_migration do
    if Rake::Task.task_defined?("action_mailbox:install:migrations")
      Rake::Task["action_mailbox:install:migrations"].invoke
    else
      Rake::Task["app:action_mailbox:install:migrations"].invoke
    end
  end

  FIXTURE_TEMPLATE_PATH = File.expand_path("../templates/fixtures.yml", __dir__)
  FIXTURE_APP_DIR_PATH  = Rails.root.join("test/fixtures/action_mailbox")
  FIXTURE_APP_PATH      = FIXTURE_APP_DIR_PATH.join("inbound_emails.yml")

  task :copy_fixtures do
    if File.exist?(FIXTURE_APP_PATH)
      puts "Won't copy Action Mailbox fixtures as it already exists"
    else
      FileUtils.mkdir FIXTURE_APP_DIR_PATH
      FileUtils.cp FIXTURE_TEMPLATE_PATH, FIXTURE_APP_PATH
    end
  end
end
