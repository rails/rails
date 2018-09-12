# frozen_string_literal: true

namespace :action_text do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration, stylesheet, and JavaScript files"
  task install: %w( environment active_storage:install copy_migration copy_stylesheet copy_fixtures )

  task :copy_migration do
    if Rake::Task.task_defined?("action_text:install:migrations")
      Rake::Task["action_text:install:migrations"].invoke
    else
      Rake::Task["app:action_text:install:migrations"].invoke
    end
  end

  STYLESHEET_TEMPLATE_PATH = File.expand_path("../templates/actiontext.css", __dir__)
  STYLESHEET_APP_PATH      = Rails.root.join("app/assets/stylesheets/actiontext.css")

  task :copy_stylesheet do
    if File.exist?(STYLESHEET_APP_PATH)
      puts "Won't copy Action Text stylesheet as it already exists"
    else
      FileUtils.cp STYLESHEET_TEMPLATE_PATH, STYLESHEET_APP_PATH
    end
  end

  FIXTURE_TEMPLATE_PATH = File.expand_path("../templates/fixtures.yml", __dir__)
  FIXTURE_APP_DIR_PATH  = Rails.root.join("test/fixtures/action_text")
  FIXTURE_APP_PATH      = FIXTURE_APP_DIR_PATH.join("rich_texts.yml")

  task :copy_fixtures do
    if File.exist?(FIXTURE_APP_PATH)
      puts "Won't copy Action Text fixtures as it already exists"
    else
      FileUtils.mkdir FIXTURE_APP_DIR_PATH
      FileUtils.cp FIXTURE_TEMPLATE_PATH, FIXTURE_APP_PATH
    end
  end
end
