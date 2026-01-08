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
    Dir.mktmpdir do |temp_dir|
      File.chmod 0700, temp_dir
      file_path = File.join(temp_dir, file_name)

      File.open(file_path, "wb", &:close)

      original_permissions = File.stat(file_path).mode.to_s(8)
      File.atomic_write(file_path, &:close)
      actual_permissions = File.stat(file_path).mode.to_s(8)

      assert_equal original_permissions, actual_permissions
    end
  end

  def test_atomic_write_preserves_file_permissions_same_directory
    Dir.mktmpdir do |temp_dir|
      File.chmod 0700, temp_dir
      file_path = File.join(temp_dir, file_name)

      File.open(file_path, "wb") do |f|
        f.chmod(0067)
      end

      original_permissions = File.stat(file_path).mode.to_s(8)
      File.atomic_write(file_path, &:close)
      actual_permissions = File.stat(file_path).mode.to_s(8)

      assert_equal original_permissions, actual_permissions
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

  def test_when_no_dir
    assert_raises Errno::ENOENT do
      File.atomic_write("/dir/does/not/exist/file.txt") { }
    end
  end

  def test_atomic_write_uses_unique_temp_file_names
    temp_file_paths = []
    2.times do
      File.atomic_write(file_name, Dir.pwd) do |file|
        temp_file_paths << file.path
      end
    end

    assert_match(/\.atomic-#{Process.pid}\.file\.tmp\.[0-9a-f]{32}\z/, temp_file_paths[0])
    assert_not_equal temp_file_paths[0], temp_file_paths[1]
  ensure
    File.unlink(file_name) rescue nil
  end

  private
    def file_name
      "atomic-#{Process.pid}.file"
    end

    def file_mode
      File.stat(file_name).mode
    end
end
