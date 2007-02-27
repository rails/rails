require File.dirname(__FILE__) + '/../abstract_unit'

class AtomicWriteTest < Test::Unit::TestCase
  
  def test_atomic_write_without_errors
    contents  = "Atomic Text"
    File.atomic_write(file_name) do |file|
      file.write(contents)
      assert !File.exists?(file_name)
    end
    assert File.exists?(file_name)
    assert_equal contents, File.read(file_name)
  ensure
    File.unlink(file_name)
  end
  
  def test_atomic_write_doesnt_write_when_block_raises
    File.atomic_write(file_name) do |file|
      file.write("testing")
      raise "something bad"
    end
  rescue
    assert !File.exists?(file_name)
  end
  
  def file_name
    "atomic.file"
  end
end
