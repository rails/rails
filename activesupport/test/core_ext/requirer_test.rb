require 'abstract_unit'
require 'active_support/core_ext/requirer'

class ArrayTest < ActiveSupport::TestCase
  def test_append_extension
    list = [1, [], 'hoge', 'fuga.rb']
    assert_equal [1, [], 'hoge.rb', 'fuga.rb'], list.append_extension
  end
end

class RequirerTest < ActiveSupport::TestCase
  MOCK_PATH = '/Your/App/Path/requirer.rb'.freeze

  def test_initialize_without_parameter_exclude
    rq = Requirer.new(MOCK_PATH)

    assert_equal rq.send(:dir, MOCK_PATH), rq.instance_variable_get(:@cwd)
    assert_equal [], rq.instance_variable_get(:@excluded)
  end

  def test_initialize_with_parameter_exclude
    files_to_be_excluded = %w(a b c.rb)
    rq = Requirer.new(MOCK_PATH, exclude: files_to_be_excluded)

    assert_equal(rq.send(:dir, MOCK_PATH), rq.instance_variable_get(:@cwd))
    assert_equal(
      %w(a b c).map { |f| ['/Your/App/Path/requirer', f].join('/') },
      rq.instance_variable_get(:@excluded))
  end

  def test_dir
    rq           = Requirer.new(MOCK_PATH)
    return_value = rq.send(:dir, MOCK_PATH)

    assert_equal Pathname, return_value.class
    assert_equal '/Your/App/Path/requirer', return_value.to_s
  end

  def test_normalize_files
    rq           = Requirer.new(MOCK_PATH)
    files        = %w(x yarb z.rb)
    return_value = rq.send(:normalize_files, files)

    assert_equal(
      %w(x yarb z).map { |f| ['/Your/App/Path/requirer', f].join('/') },
      return_value)
  end

  fork do
    def test_require
      files_to_be_excluded = %w(wrap.rb access)
      path  = "#{Rails.root}/lib/active_support/core_ext/array"
      files =
        %w(conversions extract_options grouping inquiry
           prepend_and_append)

      Requirer.new(path, exclude: files_to_be_excluded).require

      files.each { |f| assert_equal false, require("#{path}/#{f}") }

      files_to_be_excluded.each do |f|
        assert_equal true, require("#{path}/#{File.basename(f)}")
      end
    end
  end
end
