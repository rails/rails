require "abstract_unit"
require "active_support/core_ext/file"

class AtomicWriteTest < ActiveSupport::TestCase
  def test_atomic_write_without_errors
    contents = "Atomic Text"
    File.atomic_write(file_name, Dir.pwd) do |file|
      file.write(contents)
      assert !File.exist?(file_name)
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
    assert !File.exist?(file_name)
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
      assert !File.exist?(file_name)
    end
    assert File.exist?(file_name)
    assert_equal File.probe_stat_in(Dir.pwd).mode, file_mode
    assert_equal contents, File.read(file_name)
  ensure
    File.unlink(file_name) rescue nil
  end

  def test_atomic_write_returns_result_from_yielded_block
    block_return_value = File.atomic_write(file_name, Dir.pwd) do |file|
      "Hello world!"
    end

    assert_equal "Hello world!", block_return_value
  ensure
    File.unlink(file_name) rescue nil
  end

  private
    def file_name
      "atomic.file"
    end

    def file_mode
      File.stat(file_name).mode
    end
end
