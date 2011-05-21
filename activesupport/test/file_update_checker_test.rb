require 'abstract_unit'
require 'test/unit'
require 'fileutils'

MTIME_FIXTURES_PATH = File.expand_path("../fixtures", __FILE__)

class FileUpdateCheckerTest < Test::Unit::TestCase
  FILES = %w(1.txt 2.txt 3.txt)

  def setup
    FileUtils.touch(FILES)
  end

  def teardown
    FileUtils.rm(FILES)
  end

  def test_should_not_execute_the_block_if_no_paths_are_given
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new([]){ i += 1 }
    checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_invoke_the_block_on_first_call_if_it_does_not_calculate_last_updated_at_on_load
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_not_invoke_the_block_on_first_call_if_it_calculates_last_updated_at_on_load
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES, true){ i += 1 }
    checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_not_invoke_the_block_if_no_file_has_changed
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    5.times { checker.execute_if_updated }
    assert_equal 1, i
  end

  def test_should_invoke_the_block_if_a_file_has_changed
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    checker.execute_if_updated
    sleep(1)
    FileUtils.touch(FILES)
    checker.execute_if_updated
    assert_equal 2, i
  end
end
