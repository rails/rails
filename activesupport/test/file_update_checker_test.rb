require 'abstract_unit'
require 'fileutils'
require 'thread'

MTIME_FIXTURES_PATH = File.expand_path("../fixtures", __FILE__)

class FileUpdateCheckerWithEnumerableTest < ActiveSupport::TestCase
  FILES = %w(1.txt 2.txt 3.txt)

  def setup
    FileUtils.mkdir_p("tmp_watcher")
    FileUtils.touch(FILES)
  end

  def teardown
    FileUtils.rm_rf("tmp_watcher")
    FileUtils.rm_rf(FILES)
  end

  def test_should_not_execute_the_block_if_no_paths_are_given
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new([]){ i += 1 }
    checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_not_invoke_the_block_if_no_file_has_changed
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    5.times { assert !checker.execute_if_updated }
    assert_equal 0, i
  end

  def test_should_invoke_the_block_if_a_file_has_changed
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    sleep(1)
    FileUtils.touch(FILES)
    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_be_robust_enough_to_handle_deleted_files
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    FileUtils.rm(FILES)
    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_be_robust_to_handle_files_with_wrong_modified_time
    i = 0
    now = Time.now
    time = Time.mktime(now.year + 1, now.month, now.day) # wrong mtime from the future
    File.utime time, time, FILES[2]

    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }

    sleep(1)
    FileUtils.touch(FILES[0..1])

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_cache_updated_result_until_execute
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES){ i += 1 }
    assert !checker.updated?

    sleep(1)
    FileUtils.touch(FILES)

    assert checker.updated?
    checker.execute
    assert !checker.updated?
  end

  def test_should_invoke_the_block_if_a_watched_dir_changed_its_glob
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new([], "tmp_watcher" => [:txt]){ i += 1 }
    FileUtils.cd "tmp_watcher" do
      FileUtils.touch(FILES)
    end
    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_not_invoke_the_block_if_a_watched_dir_changed_its_glob
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new([], "tmp_watcher" => :rb){ i += 1 }
    FileUtils.cd "tmp_watcher" do
      FileUtils.touch(FILES)
    end
    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_not_block_if_a_strange_filename_used
    FileUtils.mkdir_p("tmp_watcher/valid,yetstrange,path,")
    FileUtils.touch(FILES.map { |file_name| "tmp_watcher/valid,yetstrange,path,/#{file_name}" })

    test = Thread.new do
      ActiveSupport::FileUpdateChecker.new([],"tmp_watcher/valid,yetstrange,path," => :txt) { i += 1 }
      Thread.exit
    end
    test.priority = -1
    test.join(5)

    assert !test.alive?
  end

  def test_filters_of_file_update_checker_when_listening
    filter = /1\.txt/
    checker = ActiveSupport::FileUpdateChecker.new(FILES, {}, {:filter => filter, :recurse => true})
    assert !checker.updated?

    sleep(1)
    FileUtils.touch(FILES)

    Thread.new do
      checker.start_listening
    end

    start_time = Time.now
    until !checker.changed_files.empty? || Time.now - start_time > 5
      sleep 0.1
    end

    assert_equal 1, checker.changed_files.size
  ensure
    checker.stop_listening
  end

  def test_filters_of_file_update_checker_no_listening
    i = 0
    filter = /1\.txt/
    checker = ActiveSupport::FileUpdateChecker.new(FILES, {}, {:filter => filter}) { i += 1 }
    assert !checker.updated?

    sleep(1)
    FileUtils.touch(FILES)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_ignores_of_file_update_checker_no_listening
    i = 0
    ignore = /txt/
    checker = ActiveSupport::FileUpdateChecker.new(FILES, {}, {:ignore => ignore}) { i += 1 }
    assert !checker.updated?

    sleep(1)
    FileUtils.touch(FILES)

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_no_recursion_when_recurse_is_set_to_false
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(FILES, {}, {:recurse => false}){ i += 1 }
    assert !checker.updated?

    sleep(1)
    FileUtils.cd "tmp_watcher" do
      FileUtils.touch(FILES)
    end

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_recursion_works_with_files_in_subdirectory
    i = 0
    checker = ActiveSupport::FileUpdateChecker.new(["tmp_watcher"], {}, {:recurse => true}){ i += 1 }
    assert !checker.updated?

    sleep(1)
    FileUtils.cd "tmp_watcher" do
      FileUtils.touch(FILES)
    end

    assert checker.execute_if_updated
    assert_equal 1, i
    assert_equal 3, checker.changed_files.size
  end
end
