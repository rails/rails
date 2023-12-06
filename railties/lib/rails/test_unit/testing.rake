# frozen_string_literal: true

require "minitest"
require "rails/test_unit/runner"

task default: :test

desc "Run all tests in test folder except system ones"
task :test do
  Rails::TestUnit::Runner.run_from_rake("test", Array(ENV["TEST"]))
end

namespace :test do
  task run: %w[test]

  desc "Reset the database and run `bin/rails test`"
  task :db do
    success = system({ "RAILS_ENV" => ENV.fetch("RAILS_ENV", "test") }, "rake", "db:test:prepare", "test")
    success || exit(false)
  end

  [
    *Rails::TestUnit::Runner::TEST_FOLDERS,
    :all,
    :generators,
    :units,
    :functionals,
    :system,
  ].each do |name|
    task name do
      Rails::TestUnit::Runner.run_from_rake("test:#{name}")
    end
  end
end
