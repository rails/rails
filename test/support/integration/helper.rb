ENV["RAILS_ENV"] = "test"
require File.expand_path("../../../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"
Rails.backtrace_cleaner.remove_silencers!

require_relative 'test_case_helpers'
ActiveSupport::TestCase.send(:include, TestCaseHelpers)

JobsManager.current_manager.setup
JobsManager.current_manager.start_workers
Minitest.after_run { JobsManager.current_manager.stop_workers }

