require 'test/unit'
require 'fileutils'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../lib"
require 'generators'

class GeneratorsTestCase < Test::Unit::TestCase
  include FileUtils

  def destination_root
    @destination_root ||= File.expand_path("#{File.dirname(__FILE__)}/../fixtures/tmp")
  end

  def setup
    rm_rf(destination_root)
    mkdir_p(destination_root)
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

  def assert_file(relative, *contents)
    absolute = File.join(destination_root, relative)
    assert File.exists?(absolute)

    contents.each do |content|
      case content
        when String
          assert_equal content, File.read(absolute)
        when Regexp
          assert_match content, File.read(absolute)
      end
    end
  end

  def assert_no_file(relative, content=nil)
    absolute = File.join(destination_root, relative)
    assert !File.exists?(absolute)
  end
end
