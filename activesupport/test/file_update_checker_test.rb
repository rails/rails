require 'abstract_unit'
require 'fileutils'
require 'thread'
require 'file_update_checker_with_enumerable_test_cases'

MTIME_FIXTURES_PATH = File.expand_path("../fixtures", __FILE__)

class FileUpdateCheckerWithEnumerableTest < ActiveSupport::TestCase
  include FileUpdateCheckerWithEnumerableTestCases
  def build_new_watcher(files, dirs={}, &block)
    ActiveSupport::FileUpdateChecker.new(files, dirs, &block)
  end
end
