require File.join(File.dirname(__FILE__), '..', 'abstract_unit')


module TestFileUtils
  def file_name() File.basename(__FILE__) end
  def file_path() File.expand_path(__FILE__) end
  def file_data() File.open(file_path, 'rb') { |f| f.read } end
end


class SendFileController < ActionController::Base
  include TestFileUtils
  layout "layouts/standard" # to make sure layouts don't interfere

  attr_writer :options
  def options() @options ||= {} end

  def file() send_file(file_path, options) end
  def data() send_data(file_data, options) end

  def rescue_action(e) raise end
end

SendFileController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class SendFileTest < Test::Unit::TestCase
  include TestFileUtils

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
    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end

  def test_file_stream
    response = nil
    assert_nothing_raised { response = process('file') }
    assert_not_nil response
    assert_kind_of Proc, response.body

    require 'stringio'
    output = StringIO.new
    output.binmode
    assert_nothing_raised { response.body.call(response, output) }
    assert_equal file_data, output.string
  end

  def test_data
    response = nil
    assert_nothing_raised { response = process('data') }
    assert_not_nil response

    assert_kind_of String, response.body
    assert_equal file_data, response.body
  end

  # Test that send_file_headers! is setting the correct HTTP headers.
  def test_send_file_headers!
    options = {
      :length => 1,
      :type => 'type',
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
    assert_equal 1, h['Content-Length']
    assert_equal 'type', h['Content-Type']
    assert_equal 'disposition; filename="filename"', h['Content-Disposition']
    assert_equal 'binary', h['Content-Transfer-Encoding']

    # test overriding Cache-Control: no-cache header to fix IE open/save dialog
    @controller.headers = { 'Cache-Control' => 'no-cache' }
    @controller.send(:send_file_headers!, options)
    h = @controller.headers
    assert_equal 'private', h['Cache-Control']
  end

  %w(file data).each do |method|
    define_method "test_send_#{method}_status" do
      @controller.options = { :stream => false, :status => 500 }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal '500 Internal Server Error', @controller.headers['Status']
    end

    define_method "test_default_send_#{method}_status" do
      @controller.options = { :stream => false }
      assert_nothing_raised { assert_not_nil process(method) }
      assert_equal ActionController::Base::DEFAULT_RENDER_STATUS_CODE, @controller.headers['Status']
    end
  end
end
