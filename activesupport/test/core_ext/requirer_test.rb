require 'abstract_unit'
require 'active_support/core_ext/requirer'

class ArrayTest < ActiveSupport::TestCase
  def test_append_extension
    list = [1, [], 'hogerb', 'fuga.rb']
    assert_equal [1, [], 'hogerb.rb', 'fuga.rb'], list.append_extension
  end
end

class RequirerTest < ActiveSupport::TestCase
  MOCK_PATH      = '/tmp'.freeze
  MOCK_BASE_FILE = '/tmp.rb'.freeze
  MOCK_FILES     = %w(a.rb b.rb c.rb).map { |f| [MOCK_PATH, f].join('/') }

  def setup
    FileUtils.touch MOCK_FILES
  end

  def cleanup
    FileUtils.rm MOCK_FILES
  end

  def test_initialize_without_parameter_exclude
    setup
    rq = Requirer.new(MOCK_PATH)

    assert_equal rq.send(:dir, MOCK_BASE_FILE), rq.instance_variable_get(:@cwd)
    assert_equal [], rq.instance_variable_get(:@excluded)
  ensure
    cleanup
  end

  def test_initialize_with_parameter_exclude
    setup
    files_to_be_excluded = %w(b c.rb)
    rq = Requirer.new(MOCK_BASE_FILE, exclude: files_to_be_excluded)

    assert_equal(rq.send(:dir, MOCK_BASE_FILE), rq.instance_variable_get(:@cwd))
    assert_equal %w(/tmp/b /tmp/c), rq.instance_variable_get(:@excluded)
  ensure
    cleanup
  end

  def test_dir
    setup
    rq           = Requirer.new(MOCK_BASE_FILE)
    return_value = rq.send(:dir, MOCK_BASE_FILE)

    assert_kind_of Pathname, return_value
    assert_equal MOCK_PATH, return_value.to_s
  ensure
    cleanup
  end

  def test_dir_which_does_not_exist
    assert_raise LoadError do
      Requirer.new('/tmp/this_does_not_exist.rb')
    end
  end

  def test_normalize_files
    setup
    rq           = Requirer.new(MOCK_BASE_FILE)
    files        = %w(x yarb z.rb)
    return_value = rq.send(:normalize_files, files)

    assert_equal %w(/tmp/x /tmp/yarb /tmp/z), return_value
  ensure
    cleanup
  end

  def test_require
    setup
    files_to_be_excluded = %w(b c.rb)
    Requirer.new(MOCK_BASE_FILE, exclude: files_to_be_excluded).require_all

    %w(a).each { |f| assert_equal false, require("#{MOCK_PATH}/#{f}") }

    files_to_be_excluded.each do |f|
      assert_equal true, require("#{MOCK_PATH}/#{File.basename(f)}")
    end
  ensure
    cleanup
  end
end
