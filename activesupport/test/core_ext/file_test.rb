# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/file"

class AtomicWriteTest < ActiveSupport::TestCase
  def test_atomic_write_without_errors
    contents = "Atomic Text"
    File.atomic_write(file_name, Dir.pwd) do |file|
      file.write(contents)
      assert_not File.exist?(file_name)
    end
    assert File.exist?(file_name)
    assert_equal contents, File.read(file_name)
  ensure
    File.unlink(file_name) rescue nil
  end

  def test_atomic_write_doesnt_write_when_block_raises
    File.atomic_write(file_name) do |file|
      file.write("testing")
      raise "something bad"
    end
  rescue
    assert_not File.exist?(file_name)
  end

  def test_atomic_write_preserves_file_permissions
    contents = "Atomic Text"
    File.open(file_name, "w", 0755) do |file|
      file.write(contents)
      assert File.exist?(file_name)
    end
    assert File.exist?(file_name)
    assert_equal 0100755 & ~File.umask, file_mode
    assert_equal contents, File.read(file_name)

    File.atomic_write(file_name, Dir.pwd) do |file|
      file.write(contents)
      assert File.exist?(file_name)
    end
    assert File.exist?(file_name)
    assert_equal 0100755 & ~File.umask, file_mode
    assert_equal contents, File.read(file_name)
  ensure
    File.unlink(file_name) rescue nil
  end

  def test_atomic_write_preserves_default_file_permissions
    contents = "Atomic Text"
    File.atomic_write(file_name, Dir.pwd) do |file|
      file.write(contents)
      assert_not File.exist?(file_name)
    end
    assert File.exist?(file_name)
    assert_equal File.probe_stat_in(Dir.pwd).mode, file_mode
    assert_equal contents, File.read(file_name)
  ensure
    File.unlink(file_name) rescue nil
  end

  def test_atomic_write_preserves_file_permissions_same_directory
    Dir.mktmpdir do |temp_dir|
      File.chmod 0700, temp_dir

      probed_permissions = File.probe_stat_in(temp_dir).mode.to_s(8)

      File.atomic_write(File.join(temp_dir, file_name), &:close)

      actual_permissions = File.stat(File.join(temp_dir, file_name)).mode.to_s(8)

      assert_equal actual_permissions, probed_permissions
    end
  end

  def test_atomic_write_returns_result_from_yielded_block
    block_return_value = File.atomic_write(file_name, Dir.pwd) do |file|
      "Hello world!"
    end

    assert_equal "Hello world!", block_return_value
  ensure
    File.unlink(file_name) rescue nil
  end

  def test_probe_stat_in_when_no_dir
    assert_nil File.probe_stat_in("/dir/does/not/exist")
  end

  private
    def file_name
      "atomic-#{Process.pid}.file"
    end

    def file_mode
      File.stat(file_name).mode
    end
end
