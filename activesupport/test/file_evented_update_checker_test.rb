require 'abstract_unit'
require 'fileutils'
require 'thread'
require 'file_update_checker_with_enumerable_test_cases'

MTIME_FIXTURES_PATH = File.expand_path("../fixtures", __FILE__)

class FileEventedUpdateCheckerWithEnumerableTest < ActiveSupport::TestCase
	include FileUpdateCheckerWithEnumerableTestCases
  def build_new_watcher(files, dirs={}, &block)
    ActiveSupport::FileEventedUpdateChecker.new(files, dirs, &block)
  end

  def test_modified_should_become_true_when_watched_file_is_updated
  	watcher = ActiveSupport::FileEventedUpdateChecker.new(FILES){ i += 1 }
  	assert_equal watcher.updated?, false
  	FileUtils.rm(FILES)
  	sleep 1
  	assert_equal watcher.updated?, true
  end
end
