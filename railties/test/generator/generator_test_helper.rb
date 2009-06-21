require 'test/unit'
require 'fileutils'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../lib"

# For this while, let's load all generators by hand
require 'generator/generators/app/app_generator'

class GeneratorTestCase < Test::Unit::TestCase
  include FileUtils

  def destination_root
    @destination_root ||= File.expand_path("#{File.dirname(__FILE__)}/../fixtures/tmp")
  end

  def setup
    mkdir_p(destination_root)
    rm_rf(destination_root)
  end

  def test_truth
    # don't complain, test/unit
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure 
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end
  alias :silence :capture

  def assert_file(relative, content=nil)
    absolute = File.join(destination_root, relative)
    assert File.exists?(absolute)

    case content
      when String
        assert_equal content, File.read(absolute)
      when Regexp
        assert_match content, File.read(absolute)
    end
  end

  def assert_no_file(relative, content=nil)
    absolute = File.join(destination_root, relative)
    assert !File.exists?(absolute)
  end
end
