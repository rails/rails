# frozen_string_literal: true

puts "\n\n*** rake aj:integration:#{ENV['AJ_ADAPTER']} ***\n"

ENV["RAILS_ENV"] = "test"
ActiveJob::Base.queue_name_prefix = nil

require "rails/generators/rails/app/app_generator"

require "tmpdir"
dummy_app_path     = Dir.mktmpdir + "/dummy"
dummy_app_template = File.expand_path("dummy_app_template.rb",  __dir__)
args = Rails::Generators::ARGVScrubber.new(["new", dummy_app_path, "--skip-gemfile", "--skip-bundle",
  "--skip-git", "--skip-spring", "-d", "sqlite3", "--skip-javascript", "--force", "--quiet",
  "--template", dummy_app_template]).prepare!
Rails::Generators::AppGenerator.start args

require "#{dummy_app_path}/config/environment.rb"

ActiveRecord::Migrator.migrations_paths = [ Rails.root.join("db/migrate").to_s ]
ActiveRecord::Tasks::DatabaseTasks.migrate
require "rails/test_help"

Rails.backtrace_cleaner.remove_silencers!

require_relative "test_case_helpers"
ActiveSupport::TestCase.include(TestCaseHelpers)

JobsManager.current_manager.start_workers

Minitest.after_run do
  JobsManager.current_manager.stop_workers
  JobsManager.current_manager.clear_jobs
end
