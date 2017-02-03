require "abstract_unit"

module TestApiFileUtils
  def file_path() File.expand_path(__FILE__) end
  def file_data() @data ||= File.open(file_path, "rb") { |f| f.read } end
end

class DataStreamingApiController < ActionController::API
  include TestApiFileUtils

  def one; end
  def two
    send_data(file_data, {})
  end
end

class DataStreamingApiTest < ActionController::TestCase
  include TestApiFileUtils
  tests DataStreamingApiController

  def test_data
    response = process("two")
    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end
end
