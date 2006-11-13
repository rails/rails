require File.dirname(__FILE__) + '/../abstract_unit'

class CaptureController < ActionController::Base
  def self.controller_name; "test"; end
  def self.controller_path; "test"; end

  def content_for
    render :layout => "talk_from_action"
  end

  def erb_content_for
    render :layout => "talk_from_action"
  end

  def block_content_for
    render :layout => "talk_from_action"
  end

  def non_erb_block_content_for
    render :layout => "talk_from_action"
  end

  def rescue_action(e) raise end
end

CaptureController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class CaptureTest < Test::Unit::TestCase
  def setup
    @controller = CaptureController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_simple_capture
    get :capturing
    assert_equal "Dreamy days", @response.body.strip
  end

  def test_content_for
    get :content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_erb_content_for
    get :content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_block_content_for
    get :block_content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_non_erb_block_content_for
    get :non_erb_block_content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_update_element_with_capture
    assert_deprecated 'update_element_function' do
      get :update_element_with_capture
    end
    assert_equal(
      "<script type=\"text/javascript\">\n//<![CDATA[\n$('products').innerHTML = '\\n  <p>Product 1</p>\\n  <p>Product 2</p>\\n';\n\n//]]>\n</script>" +
        "\n\n$('status').innerHTML = '\\n  <b>You bought something!</b>\\n';",
      @response.body.strip
    )
  end

  private
  def expected_content_for_output
    "<title>Putting stuff in the title!</title>\n\nGreat stuff!"
  end
end
