# frozen_string_literal: true

require "abstract_unit"

module TestFileUtils
  def file_name() File.basename(__FILE__) end
  def file_path() __FILE__ end
  def file_data() @data ||= File.open(file_path, "rb") { |f| f.read } end
end

class SendFileController < ActionController::Base
  include TestFileUtils
  include ActionController::Testing
  layout "layouts/standard" # to make sure layouts don't interfere

  before_action :file, only: :file_from_before_action

  attr_writer :options
  def options
    @options ||= {}
  end

  def file
    send_file(file_path, options)
  end

  def file_from_before_action
    raise "No file sent from before action."
  end

  def test_send_file_headers_bang
    options = {
      type: Mime[:png],
      disposition: "disposition",
      filename: "filename"
    }

    send_data "foo", options
  end

  def test_send_file_headers_with_disposition_as_a_symbol
    options = {
      type: Mime[:png],
      disposition: :disposition,
      filename: "filename"
    }

    send_data "foo", options
  end

  def test_send_file_headers_with_mime_lookup_with_symbol
    options = { type: :png }

    send_data "foo", options
  end

  def test_send_file_headers_with_bad_symbol
    options = { type: :this_type_is_not_registered }
    send_data "foo", options
  end

  def test_send_file_headers_with_nil_content_type
    options = { type: nil }
    send_data "foo", options
  end

  def test_send_file_headers_guess_type_from_extension
    options = { filename: params[:filename] }
    send_data "foo", options
  end

  def data
    send_data(file_data, options)
  end
end

class SendFileWithActionControllerLive < SendFileController
  include ActionController::Live
end

class SendFileTest < ActionController::TestCase
  include TestFileUtils

  def setup
    @controller = SendFileController.new
  end

  def test_file_nostream
    @controller.options = { stream: false }
    response = nil
    assert_nothing_raised { response = process("file") }
    assert_not_nil response
    body = response.body
    assert_kind_of String, body
    assert_equal file_data, body
  end

  def test_file_stream
    response = nil
    assert_nothing_raised { response = process("file") }
    assert_not_nil response
    assert_respond_to response.stream, :each
    assert_respond_to response.stream, :to_path

    require "stringio"
    output = StringIO.new
    output.binmode
    output.string.force_encoding(file_data.encoding)
    response.body_parts.each { |part| output << part.to_s }
    assert_equal file_data, output.string
  end

  def test_file_url_based_filename
    @controller.options = { url_based_filename: true }
    response = nil
    assert_nothing_raised { response = process("file") }
    assert_not_nil response
    assert_equal "attachment", response.headers["Content-Disposition"]
  end

  def test_data
    response = nil
    assert_nothing_raised { response = process("data") }
    assert_not_nil response

    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end

  def test_headers_after_send_shouldnt_include_charset
    response = process("data")
    assert_equal "application/octet-stream", response.headers["Content-Type"]

    response = process("file")
    assert_equal "application/octet-stream", response.headers["Content-Type"]
  end

  # Test that send_file_headers! is setting the correct HTTP headers.
  def test_send_file_headers_bang
    # Do it a few times: the resulting headers should be identical
    # no matter how many times you send with the same options.
    # Test resolving Ticket #458.
    5.times do
      get :test_send_file_headers_bang

      assert_equal "image/png", response.content_type
      assert_equal 'disposition; filename="filename"', response.get_header("Content-Disposition")
      assert_equal "binary", response.get_header("Content-Transfer-Encoding")
      assert_equal "private", response.get_header("Cache-Control")
    end
  end

  def test_send_file_headers_with_disposition_as_a_symbol
    get :test_send_file_headers_with_disposition_as_a_symbol

    assert_equal 'disposition; filename="filename"', response.get_header("Content-Disposition")
  end

  def test_send_file_headers_with_mime_lookup_with_symbol
    get __method__
    assert_equal "image/png", response.content_type
  end

  def test_send_file_headers_with_bad_symbol
    error = assert_raise(ArgumentError) { get __method__ }
    assert_equal "Unknown MIME type this_type_is_not_registered", error.message
  end

  def test_send_file_headers_with_nil_content_type
    error = assert_raise(ArgumentError) { get __method__ }
    assert_equal ":type option required", error.message
  end

  def test_send_file_headers_guess_type_from_extension
    {
      "image.png" => "image/png",
      "image.jpeg" => "image/jpeg",
      "image.jpg" => "image/jpeg",
      "image.tif" => "image/tiff",
      "image.gif" => "image/gif",
      "movie.mp4" => "video/mp4",
      "file.zip" => "application/zip",
      "file.unk" => "application/octet-stream",
      "zip" => "application/octet-stream"
    }.each do |filename, expected_type|
      get __method__, params: { filename: filename }
      assert_equal expected_type, response.content_type
    end
  end

  def test_send_file_with_default_content_disposition_header
    process("data")
    assert_equal "attachment", @controller.headers["Content-Disposition"]
  end

  def test_send_file_without_content_disposition_header
    @controller.options = { disposition: nil }
    process("data")
    assert_nil @controller.headers["Content-Disposition"]
  end

  def test_send_file_from_before_action
    response = nil
    assert_nothing_raised { response = process("file_from_before_action") }
    assert_not_nil response

    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end

  %w(file data).each do |method|
    define_method "test_send_#{method}_status" do
      @controller.options = { stream: false, status: 500 }
      assert_not_nil process(method)
      assert_equal 500, @response.status
    end

    define_method "test_send_#{method}_content_type" do
      @controller.options = { stream: false, content_type: "application/x-ruby" }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal "application/x-ruby", @response.content_type
    end

    define_method "test_default_send_#{method}_status" do
      @controller.options = { stream: false }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal 200, @response.status
    end
  end

  def test_send_file_with_action_controller_live
    @controller = SendFileWithActionControllerLive.new
    @controller.options = { content_type: "application/x-ruby" }

    response = process("file")
    assert_equal 200, response.status
  end

  def test_send_file_charset_with_type_options_key
    @controller = SendFileWithActionControllerLive.new
    @controller.options = { type: "text/calendar; charset=utf-8" }
    response = process("file")
    assert_equal "text/calendar; charset=utf-8", response.headers["Content-Type"]
  end

  def test_send_file_charset_with_type_options_key_without_charset
    @controller = SendFileWithActionControllerLive.new
    @controller.options = { type: "image/png" }
    response = process("file")
    assert_equal "image/png", response.headers["Content-Type"]
  end

  def test_send_file_charset_with_content_type_options_key
    @controller = SendFileWithActionControllerLive.new
    @controller.options = { content_type: "text/calendar" }
    response = process("file")
    assert_equal "text/calendar", response.headers["Content-Type"]
  end
end
