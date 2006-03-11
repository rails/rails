require File.dirname(__FILE__) + '/../abstract_unit'

class RespondToController < ActionController::Base
  def html_xml_or_rss
    respond_to do |type|
      type.html { render :text => "HTML"    }
      type.xml  { render :text => "XML"     }
      type.rss  { render :text => "RSS"     }
      type.all  { render :text => "Nothing" }
    end
  end
  
  def js_or_html
    respond_to do |type|
      type.html { render :text => "HTML"    }
      type.js   { render :text => "JS"      }
      type.all  { render :text => "Nothing" }
    end
  end

  def html_or_xml
    respond_to do |type|
      type.html { render :text => "HTML"    }
      type.xml  { render :text => "XML"     }
      type.all  { render :text => "Nothing" }
    end
  end
  
  def just_xml
    respond_to do |type|
      type.xml  { render :text => "XML" }
    end
  end

  def rescue_action(e)
    raise unless ActionController::MissingTemplate === e
  end
end

class MimeControllerTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @controller = RespondToController.new
    @request.host = "www.example.com"
  end
  
  def test_html
    @request.env["HTTP_ACCEPT"] = "text/html"
    get :js_or_html
    assert_equal 'HTML', @response.body
    
    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_response 406
  end

  def test_all
    @request.env["HTTP_ACCEPT"] = "*/*"
    get :js_or_html
    assert_equal 'HTML', @response.body # js is not part of all

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_equal 'XML', @response.body
  end

  def test_xml
    @request.env["HTTP_ACCEPT"] = "application/xml"
    get :html_xml_or_rss
    assert_equal 'XML', @response.body
  end

  def test_js_or_html
    @request.env["HTTP_ACCEPT"] = "text/javascript; text/html"
    get :js_or_html
    assert_equal 'JS', @response.body

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_response 406
  end

  def test_js_or_anything
    @request.env["HTTP_ACCEPT"] = "text/javascript; */*"
    get :js_or_html
    assert_equal 'JS', @response.body

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_equal 'XML', @response.body
  end
end