# encoding: utf-8
require 'abstract_unit'

module TestFileUtils
  def file_name() File.basename(__FILE__) end
  def file_path() File.expand_path(__FILE__) end
  def file_data() @data ||= File.open(file_path, 'rb') { |f| f.read } end
end

class SendFileController < ActionController::Base
  include TestFileUtils
  layout "layouts/standard" # to make sure layouts don't interfere

  attr_writer :options
  def options
    @options ||= {}
  end

  def file
    send_file(file_path, options)
  end

  def data
    send_data(file_data, options)
  end
end

class SendFileTest < ActionController::TestCase
  tests SendFileController
  include TestFileUtils

  Mime::Type.register "image/png", :png unless defined? Mime::PNG

  def setup
    @controller = SendFileController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  end

  def test_file_nostream
    @controller.options = { :stream => false }
    response = nil
    assert_nothing_raised { response = process('file') }
    assert_not_nil response
    body = response.body
    assert_kind_of String, body
    assert_equal file_data, body
  end

  def test_file_stream
    response = nil
    assert_nothing_raised { response = process('file') }
    assert_not_nil response
    assert_respond_to response.stream, :each
    assert_respond_to response.stream, :to_path

    require 'stringio'
    output = StringIO.new
    output.binmode
    output.string.force_encoding(file_data.encoding)
    response.body_parts.each { |part| output << part.to_s }
    assert_equal file_data, output.string
  end

  def test_file_url_based_filename
    @controller.options = { :url_based_filename => true }
    response = nil
    assert_nothing_raised { response = process('file') }
    assert_not_nil response
    assert_equal "attachment", response.headers["Content-Disposition"]
  end

  def test_data
    response = nil
    assert_nothing_raised { response = process('data') }
    assert_not_nil response

    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end

  def test_headers_after_send_shouldnt_include_charset
    response = process('data')
    assert_equal "application/octet-stream", response.headers["Content-Type"]

    response = process('file')
    assert_equal "application/octet-stream", response.headers["Content-Type"]
  end

  # Test that send_file_headers! is setting the correct HTTP headers.
  def test_send_file_headers_bang
    options = {
      :type => Mime::PNG,
      :disposition => 'disposition',
      :filename => 'filename'
    }

    # Do it a few times: the resulting headers should be identical
    # no matter how many times you send with the same options.
    # Test resolving Ticket #458.
    @controller.headers = {}
    @controller.send(:send_file_headers!, options)
    @controller.send(:send_file_headers!, options)
    @controller.send(:send_file_headers!, options)

    h = @controller.headers
    assert_equal 'image/png', @controller.content_type
    assert_equal 'disposition; filename="filename"', h['Content-Disposition']
    assert_equal 'binary', h['Content-Transfer-Encoding']

    # test overriding Cache-Control: no-cache header to fix IE open/save dialog
    @controller.send(:send_file_headers!, options)
    @controller.response.prepare!
    assert_equal 'private', h['Cache-Control']
  end

  def test_send_file_headers_with_mime_lookup_with_symbol
    options = {
      :type => :png
    }

    @controller.headers = {}
    @controller.send(:send_file_headers!, options)

    assert_equal 'image/png', @controller.content_type
  end


  def test_send_file_headers_with_bad_symbol
    options = {
      :type => :this_type_is_not_registered
    }

    @controller.headers = {}
    assert_raise(ArgumentError){ @controller.send(:send_file_headers!, options) }
  end

  def test_send_file_headers_guess_type_from_extension
    {
      'image.png' => 'image/png',
      'image.jpeg' => 'image/jpeg',
      'image.jpg' => 'image/jpeg',
      'image.tif' => 'image/tiff',
      'image.gif' => 'image/gif',
      'movie.mpg' => 'video/mpeg',
      'file.zip' => 'application/zip',
      'file.unk' => 'application/octet-stream',
      'zip' => 'application/octet-stream'
    }.each do |filename,expected_type|
      options = { :filename => filename }
      @controller.headers = {}
      @controller.send(:send_file_headers!, options)
      assert_equal expected_type, @controller.content_type
    end
  end

  def test_send_file_with_default_content_disposition_header
    process('data')
    assert_equal 'attachment', @controller.headers['Content-Disposition']
  end

  def test_send_file_without_content_disposition_header
    @controller.options = {:disposition => nil}
    process('data')
    assert_nil @controller.headers['Content-Disposition']
  end

  %w(file data).each do |method|
    define_method "test_send_#{method}_status" do
      @controller.options = { :stream => false, :status => 500 }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal 500, @response.status
    end

    define_method "test_send_#{method}_content_type" do
      @controller.options = { :stream => false, :content_type => "application/x-ruby" }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal "application/x-ruby", @response.content_type
    end

    define_method "test_default_send_#{method}_status" do
      @controller.options = { :stream => false }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal 200, @response.status
    end
  end
end
