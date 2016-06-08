require 'abstract_unit'
require 'pathname'
require 'file_update_checker_shared_tests'

class EventedFileUpdateCheckerTest < ActiveSupport::TestCase
  include FileUpdateCheckerSharedTests

  def setup
    skip if ENV['LISTEN'] == '0'
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

  def touch(files)
    super
    wait # wait for the events to fire
  end

  def rm_f(files)
    super
    wait
  end

  test 'notifies forked processes' do
    FileUtils.touch(tmpfiles)

    checker = new_checker(tmpfiles) { }
    assert !checker.updated?

    # Pipes used for flow controll across fork.
    boot_reader,  boot_writer  = IO.pipe
    touch_reader, touch_writer = IO.pipe

    pid = fork do
      assert checker.updated?

      # Clear previous check value.
      checker.execute
      assert !checker.updated?

      # Fork is booted, ready for file to be touched
      # notify parent process.
      boot_writer.write("booted")

      # Wait for parent process to signal that file
      # has been touched.
      IO.select([touch_reader])

      assert checker.updated?
    end

    assert pid

    # Wait for fork to be booted before touching files.
    IO.select([boot_reader])
    touch(tmpfiles)

    # Notify fork that files have been touched.
    touch_writer.write("touched")

    assert checker.updated?

    Process.wait(pid)
  end
end

class EventedFileUpdateCheckerPathHelperTest < ActiveSupport::TestCase
  def pn(path)
    Pathname.new(path)
  end

  setup do
    @ph = ActiveSupport::EventedFileUpdateChecker::PathHelper.new
  end

  test '#xpath returns the expanded path as a Pathname object' do
    assert_equal pn(__FILE__).expand_path, @ph.xpath(__FILE__)
  end

  test '#normalize_extension returns a bare extension as is' do
    assert_equal 'rb', @ph.normalize_extension('rb')
  end

  test '#normalize_extension removes a leading dot' do
    assert_equal 'rb', @ph.normalize_extension('.rb')
  end

  test '#normalize_extension supports symbols' do
    assert_equal 'rb', @ph.normalize_extension(:rb)
  end

  test '#longest_common_subpath finds the longest common subpath, if there is one' do
    paths = %w(
      /foo/bar
      /foo/baz
      /foo/bar/baz/woo/zoo
    ).map { |path| pn(path) }

    assert_equal pn('/foo'), @ph.longest_common_subpath(paths)
  end

  test '#longest_common_subpath returns the root directory as an edge case' do
    paths = %w(
      /foo/bar
      /foo/baz
      /foo/bar/baz/woo/zoo
      /wadus
    ).map { |path| pn(path) }

    assert_equal pn('/'), @ph.longest_common_subpath(paths)
  end

  test '#longest_common_subpath returns nil for an empty collection' do
    assert_nil @ph.longest_common_subpath([])
  end

  test '#existing_parent returns the most specific existing ascendant' do
    wd = Pathname.getwd

    assert_equal wd, @ph.existing_parent(wd)
    assert_equal wd, @ph.existing_parent(wd.join('non-existing/directory'))
    assert_equal pn('/'), @ph.existing_parent(pn('/non-existing/directory'))
  end

  test '#filter_out_descendants returns the same collection if there are no descendants (empty)' do
    assert_equal [], @ph.filter_out_descendants([])
  end

  test '#filter_out_descendants returns the same collection if there are no descendants (one)' do
    assert_equal ['/foo'], @ph.filter_out_descendants(['/foo'])
  end

  test '#filter_out_descendants returns the same collection if there are no descendants (several)' do
    paths = %w(
      /Rails.root/app/controllers
      /Rails.root/app/models
      /Rails.root/app/helpers
    ).map { |path| pn(path) }

    assert_equal paths, @ph.filter_out_descendants(paths)
  end

  test '#filter_out_descendants filters out descendants preserving order' do
    paths = %w(
      /Rails.root/app/controllers
      /Rails.root/app/controllers/concerns
      /Rails.root/app/models
      /Rails.root/app/models/concerns
      /Rails.root/app/helpers
    ).map { |path| pn(path) }

    assert_equal paths.values_at(0, 2, 4), @ph.filter_out_descendants(paths)
  end

  test '#filter_out_descendants works on path units' do
    paths = %w(
      /foo/bar
      /foo/barrrr
    ).map { |path| pn(path) }

    assert_equal paths, @ph.filter_out_descendants(paths)
  end

  test '#filter_out_descendants deals correctly with the root directory' do
    paths = %w(
      /
      /foo
      /foo/bar
    ).map { |path| pn(path) }

    assert_equal paths.values_at(0), @ph.filter_out_descendants(paths)
  end

  test '#filter_out_descendants preserves duplicates' do
    paths = %w(
      /foo
      /foo/bar
      /foo
    ).map { |path| pn(path) }

    assert_equal paths.values_at(0, 2), @ph.filter_out_descendants(paths)
  end
end
