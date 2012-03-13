require 'abstract_unit'

module TestHTTPFileUtils
  def file_name() File.basename(__FILE__) end
  def file_path() File.expand_path(__FILE__) end
  def file_data() @data ||= File.open(file_path, 'rb') { |f| f.read } end
end

class DataStreamingHTTPController < ActionController::HTTP
  include TestHTTPFileUtils

  def one; end
  def two
    send_data(file_data, {})
  end
end

class DataStreamingHTTPTest < ActionController::TestCase
  include TestHTTPFileUtils
  tests DataStreamingHTTPController

  def test_data
    response = process('two')
    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end
end
