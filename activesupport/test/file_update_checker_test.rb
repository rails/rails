require 'abstract_unit'
require 'file_update_checker_with_enumerable_test_cases'

class FileUpdateCheckerTest < ActiveSupport::TestCase
  include FileUpdateCheckerWithEnumerableTestCases

  def build_new_watcher(files=[], dirs={}, &block)
    ActiveSupport::FileUpdateChecker.new(files, dirs, &block)
  end
end
