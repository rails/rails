require 'abstract_unit'
require 'fileutils'
require 'thread'
require 'file_update_checker_with_enumerable_test_cases'

class FileEventedUpdateCheckerTest < ActiveSupport::TestCase
  include FileUpdateCheckerWithEnumerableTestCases

  def build_new_watcher(files, dirs={}, &block)
    ActiveSupport::FileEventedUpdateChecker.new(files, dirs, &block)
  end
end
