# frozen_string_literal: true

$: << File.expand_path("test", COMPONENT_ROOT)

require "bundler/setup"

require "rails/test_unit/runner"
require "rails/test_unit/reporter"
require "rails/test_unit/line_filtering"
require "active_support"
require "active_support/test_case"

require "rake/testtask"

Rails::TestUnit::Runner.singleton_class.prepend Module.new {
   private
     def list_tests(patterns)
       tests = super
       tests.concat FileList["test/cases/adapters/#{adapter_name}/**/*_test.rb"] if patterns.empty?
       tests
     end

     def default_test_exclude_glob
       ENV["DEFAULT_TEST_EXCLUDE"] || "test/cases/adapters/*/*_test.rb"
     end

     def adapter_name
       ENV["ARCONN"] || "sqlite3"
     end
 }

ActiveSupport::TestCase.extend Rails::LineFiltering
Rails::TestUnitReporter.app_root = COMPONENT_ROOT
Rails::TestUnitReporter.executable = "bin/test"

Rails::TestUnit::Runner.parse_options(ARGV)
Rails::TestUnit::Runner.run(ARGV)
