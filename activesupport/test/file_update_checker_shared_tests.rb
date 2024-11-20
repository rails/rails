# frozen_string_literal: true

require "fileutils"

module FileUpdateCheckerSharedTests
  extend ActiveSupport::Testing::Declarative

  def tmpdir
    @tmpdir
  end

  def tmpfile(name)
    File.join(tmpdir, name)
  end

  def tmpfiles
    @tmpfiles ||= %w(foo.rb bar.rb baz.rb).map { |f| tmpfile(f) }
  end

  def run(*args)
    capture_exceptions do
      Dir.mktmpdir(nil, __dir__) { |dir| @tmpdir = dir; super }
    end
  end

  test "should not execute the block if no paths are given" do
    silence_warnings { require "listen" }
    i = 0

    checker = new_checker { i += 1 }

    assert_not checker.execute_if_updated
    assert_equal 0, i
  end

  test "should not execute the block if no files change" do
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }

    assert_not checker.execute_if_updated
    assert_equal 0, i
  end

  test "should execute the block once when files are created" do
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }

    touch(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "should execute the block once when files are modified" do
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }

    touch(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "should execute the block once when files are deleted" do
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }

    rm_f(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "updated should become true when watched files are created" do
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }
    assert_not_predicate checker, :updated?

    touch(tmpfiles)

    assert_predicate checker, :updated?
  end

  test "updated should become true when watched files are modified" do
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }
    assert_not_predicate checker, :updated?

    touch(tmpfiles)

    assert_predicate checker, :updated?
  end

  test "updated should become true when watched files are deleted" do
    i = 0

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { i += 1 }
    assert_not_predicate checker, :updated?

    rm_f(tmpfiles)

    assert_predicate checker, :updated?
  end

  test "should be robust to handle files with wrong modified time" do
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

  test "should return max_time for files with mtime = Time.at(0)" do
    i = 0

    FileUtils.touch(tmpfiles)

    time = Time.at(0) # wrong mtime from the future
    File.utime(time, time, tmpfiles[0])

    checker = new_checker(tmpfiles) { i += 1 }

    touch(tmpfiles[1..-1])

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "should cache updated result until execute" do
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }
    assert_not_predicate checker, :updated?

    touch(tmpfiles)

    assert_predicate checker, :updated?
    checker.execute
    assert_not_predicate checker, :updated?
  end

  test "should execute the block if files change in a watched directory one extension" do
    i = 0

    checker = new_checker([], tmpdir => :rb) { i += 1 }

    touch(tmpfile("foo.rb"))

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "should execute the block if files change in a watched directory any extensions" do
    i = 0

    checker = new_checker([], tmpdir => []) { i += 1 }

    touch(tmpfile("foo.rb"))

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "should execute the block if files change in a watched directory several extensions" do
    i = 0

    checker = new_checker([], tmpdir => [:rb, :txt]) { i += 1 }

    touch(tmpfile("foo.rb"))

    assert checker.execute_if_updated
    assert_equal 1, i

    touch(tmpfile("foo.txt"))

    assert checker.execute_if_updated
    assert_equal 2, i
  end

  test "should not execute the block if the file extension is not watched" do
    i = 0

    checker = new_checker([], tmpdir => :txt) { i += 1 }

    touch(tmpfile("foo.rb"))

    assert_not checker.execute_if_updated
    assert_equal 0, i
  end

  test "does not assume files exist on instantiation" do
    i = 0

    non_existing = tmpfile("non_existing.rb")
    checker = new_checker([non_existing]) { i += 1 }

    touch(non_existing)

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "detects files in new subdirectories" do
    i = 0

    checker = new_checker([], tmpdir => :rb) { i += 1 }

    subdir = tmpfile("subdir")
    mkdir(subdir)

    assert_not checker.execute_if_updated
    assert_equal 0, i

    touch(File.join(subdir, "nested.rb"))

    assert checker.execute_if_updated
    assert_equal 1, i
  end

  test "looked up extensions are inherited in subdirectories not listening to them" do
    i = 0

    subdir = tmpfile("subdir")
    FileUtils.mkdir(subdir)

    checker = new_checker([], tmpdir => :rb, subdir => :txt) { i += 1 }

    touch(tmpfile("new.txt"))

    assert_not checker.execute_if_updated
    assert_equal 0, i

    # subdir does not look for Ruby files, but its parent tmpdir does.
    touch(File.join(subdir, "nested.rb"))

    assert checker.execute_if_updated
    assert_equal 1, i

    touch(File.join(subdir, "nested.txt"))

    assert checker.execute_if_updated
    assert_equal 2, i
  end

  test "initialize raises an ArgumentError if no block given" do
    assert_raise ArgumentError do
      new_checker([])
    end
  end

  private
    def mkdir(dirs)
      FileUtils.mkdir(dirs)
    end

    def touch(files)
      FileUtils.touch(files)
    end

    def rm_f(files)
      FileUtils.rm_f(files)
    end
end
