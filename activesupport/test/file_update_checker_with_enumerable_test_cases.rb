module FileUpdateCheckerWithEnumerableTestCases
  FILES = %w(1.txt 2.txt 3.txt)

  def setup
    FileUtils.mkdir_p('tmp_watcher')
    FileUtils.touch(FILES)
  end

  def teardown
    FileUtils.rm_rf('tmp_watcher')
    FileUtils.rm_rf(FILES)
  end

  def test_should_not_execute_the_block_if_no_paths_are_given
    i = 0

    checker = build_new_watcher([]) { i += 1 }
    checker.execute_if_updated

    assert_equal 0, i
  end

  def test_should_not_invoke_the_block_if_no_file_has_changed
    i = 0

    checker = build_new_watcher(FILES) { i += 1 }

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_invoke_the_block_if_a_file_has_changed
    i = 0

    checker = build_new_watcher(FILES) { i += 1 }
    sleep 1

    FileUtils.touch(FILES)
    sleep 1

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_updated_should_become_true_when_watched_files_are_deleted
    watcher = build_new_watcher(FILES) { i += 1 }
    assert !watcher.updated?

    FileUtils.rm(FILES)
    sleep 1

    assert watcher.updated?
  end

  def test_should_be_robust_enough_to_handle_deleted_files
    i = 0

    checker = build_new_watcher(FILES) { i += 1 }
    FileUtils.rm_f(FILES)

    sleep 1

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_be_robust_to_handle_files_with_wrong_modified_time
    i = 0

    now = Time.now
    time = Time.mktime(now.year + 1, now.month, now.day) # wrong mtime from the future
    File.utime(time, time, FILES[2])

    checker = build_new_watcher(FILES) { i += 1 }
    sleep 1

    FileUtils.touch(FILES[0..1])
    sleep 1

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_cache_updated_result_until_execute
    i = 0

    checker = build_new_watcher(FILES) { i += 1 }
    assert !checker.updated?
    sleep 1

    FileUtils.touch(FILES)
    sleep 1

    assert checker.updated?
    checker.execute
    assert !checker.updated?
  end

  def test_should_invoke_the_block_if_a_watched_dir_changed_its_glob
    i = 0

    checker = build_new_watcher([], 'tmp_watcher' => [:txt]) { i += 1 }

    FileUtils.cd 'tmp_watcher' do
      FileUtils.touch(FILES)
    end
    sleep 1

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_not_invoke_the_block_if_a_watched_dir_changed_its_glob
    i = 0

    checker = build_new_watcher([], 'tmp_watcher' => :rb) { i += 1 }

    FileUtils.cd 'tmp_watcher' do
      FileUtils.touch(FILES)
    end
    sleep 1

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_not_block_with_unusual_file_names
    unusual_dirname = 'tmp_watcher/valid,yetstrange,path,'
    FileUtils.mkdir_p(unusual_dirname)
    FileUtils.touch(FILES.map { |file_name| "#{unusual_dirname}/#{file_name}" })

    test = Thread.new do
      build_new_watcher([], unusual_dirname => :txt) { i += 1 }
      Thread.exit
    end

    test.priority = -1
    test.join(5)

    assert !test.alive?
  end
end
