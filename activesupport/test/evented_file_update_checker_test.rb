# frozen_string_literal: true

require_relative "abstract_unit"
require "pathname"
require "weakref"
require_relative "file_update_checker_shared_tests"

class EventedFileUpdateCheckerTest < ActiveSupport::TestCase
  include FileUpdateCheckerSharedTests

  def setup
    skip if ENV["LISTEN"] == "0"
    require "listen"
    super
  end

  def new_checker(files = [], dirs = {}, &block)
    ActiveSupport::EventedFileUpdateChecker.new(files, dirs, &block).tap do |c|
      wait
    end
  end

  def teardown
    super
    Listen.stop
  end

  def wait
    sleep 1
  end

  def mkdir(dirs)
    super
    wait # wait for the events to fire
  end

  def touch(files)
    super
    wait # wait for the events to fire
  end

  def rm_f(files)
    super
    wait # wait for the events to fire
  end

  test "notifies forked processes" do
    skip "Forking not available" unless Process.respond_to?(:fork)

    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { }
    assert_not_predicate checker, :updated?

    # Pipes used for flow control across fork.
    boot_reader,  boot_writer  = IO.pipe
    touch_reader, touch_writer = IO.pipe

    pid = fork do
      assert_not_predicate checker, :updated?

      # Fork is booted, ready for file to be touched
      # notify parent process.
      boot_writer.write("booted")

      # Wait for parent process to signal that file
      # has been touched.
      IO.select([touch_reader])

      assert_predicate checker, :updated?
    end

    assert pid

    # Wait for fork to be booted before touching files.
    IO.select([boot_reader])
    touch(tmpfiles)

    # Notify fork that files have been touched.
    touch_writer.write("touched")

    assert_predicate checker, :updated?

    Process.wait(pid)
  end

  test "can be garbage collected" do
    # Use a separate thread to isolate objects and ensure they will be garbage collected.
    checker_ref, listener_threads = Thread.new do
      threads_before_checker = Thread.list
      checker = ActiveSupport::EventedFileUpdateChecker.new([], tmpdir => ".rb") { }

      # Wait for listener thread to start processing events.
      wait

      [WeakRef.new(checker), Thread.list - threads_before_checker]
    end.value

    # Calling `GC.start` 4 times should trigger a full GC run.
    4.times do
      GC.start
    end

    assert_not checker_ref.weakref_alive?, "EventedFileUpdateChecker was not garbage collected"
    assert_empty Thread.list & listener_threads
  end

  test "should detect changes through symlink" do
    actual_dir = File.join(tmpdir, "actual")
    linked_dir = File.join(tmpdir, "linked")

    Dir.mkdir(actual_dir)
    FileUtils.ln_s(actual_dir, linked_dir)

    checker = new_checker([], linked_dir => ".rb") { }

    assert_not_predicate checker, :updated?

    touch(File.join(actual_dir, "a.rb"))

    assert_predicate checker, :updated?
    assert checker.execute_if_updated
  end

  test "updated should become true when nonexistent directory is added later" do
    watched_dir = File.join(tmpdir, "app")
    unwatched_dir = File.join(tmpdir, "node_modules")
    not_exist_watched_dir = File.join(tmpdir, "test")

    Dir.mkdir(watched_dir)
    Dir.mkdir(unwatched_dir)

    checker = new_checker([], watched_dir => ".rb", not_exist_watched_dir => ".rb") { }

    touch(File.join(watched_dir, "a.rb"))
    assert_predicate checker, :updated?
    assert checker.execute_if_updated

    Dir.mkdir(not_exist_watched_dir)
    wait
    assert_predicate checker, :updated?
    assert checker.execute_if_updated

    touch(File.join(unwatched_dir, "a.rb"))
    assert_not_predicate checker, :updated?
    assert_not checker.execute_if_updated
  end

  test "does not stop other checkers when nonexistent directory is added later" do
    dir1 = File.join(tmpdir, "app")
    dir2 = File.join(tmpdir, "test")

    Dir.mkdir(dir2)

    checker1 = new_checker([], dir1 => ".rb") { }
    checker2 = new_checker([], dir2 => ".rb") { }

    Dir.mkdir(dir1)

    touch(File.join(dir1, "a.rb"))
    assert_predicate checker1, :updated?

    assert_not_predicate checker2, :updated?

    touch(File.join(dir2, "a.rb"))
    assert_predicate checker2, :updated?
  end
end
