require 'fileutils'

module FileUpdateCheckerWithEnumerableTestCases
  include FileUtils

  def tmpdir
    @tmpdir ||= Dir.mktmpdir(nil, __dir__)
  end

  def tmpfile(name)
    "#{tmpdir}/#{name}"
  end

  def tmpfiles
    @tmpfiles ||= %w(foo.rb bar.rb baz.rb).map {|f| tmpfile(f)}
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  def test_should_not_execute_the_block_if_no_paths_are_given
    i = 0

    checker = new_checker { i += 1 }

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_not_execute_the_block_if_no_files_change
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_should_execute_the_block_once_when_files_are_created
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }

    touch(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_execute_the_block_once_when_files_are_modified
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }

    touch(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_execute_the_block_once_when_files_are_deleted
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }

    rm_f(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i
  end


  def test_updated_should_become_true_when_watched_files_are_created
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }
    assert !checker.updated?

    touch(tmpfiles)

    assert checker.updated?
  end


  def test_updated_should_become_true_when_watched_files_are_modified
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }
    assert !checker.updated?

    touch(tmpfiles)

    assert checker.updated?
  end

  def test_updated_should_become_true_when_watched_files_are_deleted
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }
    assert !checker.updated?

    rm_f(tmpfiles)

    assert checker.updated?
  end

  def test_should_be_robust_to_handle_files_with_wrong_modified_time
    i = 0

    FileUtils.touch(tmpfiles)

    now  = Time.now
    time = Time.mktime(now.year + 1, now.month, now.day) # wrong mtime from the future
    File.utime(time, time, tmpfiles[0])

    checker = new_checker(tmpfiles) { i += 1 }

    touch(tmpfiles[1..-1])

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_cache_updated_result_until_execute
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }
    assert !checker.updated?

    touch(tmpfiles)

    assert checker.updated?
    checker.execute
    assert !checker.updated?
  end

  def test_should_execute_the_block_if_files_change_in_a_watched_directory_one_extension
    i = 0

    checker = new_checker([], tmpdir => :rb) { i += 1 }

    touch(tmpfile('foo.rb'))

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_should_execute_the_block_if_files_change_in_a_watched_directory_several_extensions
    i = 0

    checker = new_checker([], tmpdir => [:rb, :txt]) { i += 1 }

    touch(tmpfile('foo.rb'))

    assert checker.execute_if_updated
    assert_equal 1, i

    touch(tmpfile('foo.txt'))

    assert checker.execute_if_updated
    assert_equal 2, i
  end

  def test_should_not_execute_the_block_if_the_file_extension_is_not_watched
    i = 0

    checker = new_checker([], tmpdir => :txt) { i += 1 }

    touch(tmpfile('foo.rb'))

    assert !checker.execute_if_updated
    assert_equal 0, i
  end

  def test_does_not_assume_files_exist_on_instantiation
    i = 0

    non_existing = tmpfile('non_existing.rb')
    checker = new_checker([non_existing]) { i += 1 }

    touch(non_existing)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_detects_files_in_new_subdirectories
    i = 0

    checker = new_checker([], tmpdir => :rb) { i += 1 }

    subdir = tmpfile('subdir')
    mkdir(subdir)
    wait

    assert !checker.execute_if_updated
    assert_equal 0, i

    touch("#{subdir}/nested.rb")

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  def test_looked_up_extensions_are_inherited_in_subdirectories_not_listening_to_them
    i = 0

    subdir = tmpfile('subdir')
    mkdir(subdir)

    checker = new_checker([], tmpdir => :rb, subdir => :txt) { i += 1 }

    touch(tmpfile('new.txt'))

    assert !checker.execute_if_updated
    assert_equal 0, i

    # subdir does not look for Ruby files, but its parent tmpdir does.
    touch("#{subdir}/nested.rb")

    assert checker.execute_if_updated
    assert_equal 1, i

    touch("#{subdir}/nested.txt")

    assert checker.execute_if_updated
    assert_equal 2, i
  end
end
