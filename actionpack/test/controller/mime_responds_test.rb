require 'abstract_unit'

class RespondToController < ActionController::Base
  layout :set_layout

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

  def json_or_yaml
    respond_to do |type|
      type.json { render :text => "JSON" }
      type.yaml { render :text => "YAML" }
    end
  end

  def html_or_xml
    respond_to do |type|
      type.html { render :text => "HTML"    }
      type.xml  { render :text => "XML"     }
      type.all  { render :text => "Nothing" }
    end
  end

  def forced_xml
    request.format = :xml

    respond_to do |type|
      type.html { render :text => "HTML"    }
      type.xml  { render :text => "XML"     }
    end
  end

  def just_xml
    respond_to do |type|
      type.xml  { render :text => "XML" }
    end
  end

  def using_defaults
    respond_to do |type|
      type.html
      type.js
      type.xml
    end
  end

  def using_defaults_with_type_list
    respond_to(:html, :js, :xml)
  end

  def made_for_content_type
    respond_to do |type|
      type.rss  { render :text => "RSS"  }
      type.atom { render :text => "ATOM" }
      type.all  { render :text => "Nothing" }
    end
  end

  def custom_type_handling
    respond_to do |type|
      type.html { render :text => "HTML"    }
      type.custom("application/crazy-xml")  { render :text => "Crazy XML"  }
      type.all  { render :text => "Nothing" }
    end
  end

  def custom_constant_handling
    Mime::Type.register("text/x-mobile", :mobile)

    respond_to do |type|
      type.html   { render :text => "HTML"   }
      type.mobile { render :text => "Mobile" }
    end
  ensure
    Mime.module_eval { remove_const :MOBILE if const_defined?(:MOBILE) }
  end

  def custom_constant_handling_without_block
    Mime::Type.register("text/x-mobile", :mobile)

    respond_to do |type|
      type.html   { render :text => "HTML"   }
      type.mobile
    end

  ensure
    Mime.module_eval { remove_const :MOBILE if const_defined?(:MOBILE) }
  end

  def handle_any
    respond_to do |type|
      type.html { render :text => "HTML" }
      type.any(:js, :xml) { render :text => "Either JS or XML" }
    end
  end

  def handle_any_any
    respond_to do |type|
      type.html { render :text => 'HTML' }
      type.any { render :text => 'Whatever you ask for, I got it' }
    end
  end

  def all_types_with_layout
    respond_to do |type|
      type.html
      type.js
    end
  end

  def iphone_with_html_response_type
    Mime::Type.register_alias("text/html", :iphone)
    request.format = :iphone if request.env["HTTP_ACCEPT"] == "text/iphone"

    respond_to do |type|
      type.html   { @type = "Firefox" }
      type.iphone { @type = "iPhone"  }
    end

  ensure
    Mime.module_eval { remove_const :IPHONE if const_defined?(:IPHONE) }
  end

  def iphone_with_html_response_type_without_layout
    Mime::Type.register_alias("text/html", :iphone)
    request.format = "iphone" if request.env["HTTP_ACCEPT"] == "text/iphone"

    respond_to do |type|
      type.html   { @type = "Firefox"; render :action => "iphone_with_html_response_type" }
      type.iphone { @type = "iPhone" ; render :action => "iphone_with_html_response_type" }
    end

  ensure
    Mime.module_eval { remove_const :IPHONE if const_defined?(:IPHONE) }
  end

  def rescue_action(e)
    raise
  end

  protected
    def set_layout
      if ["all_types_with_layout", "iphone_with_html_response_type"].include?(action_name)
        "respond_to/layouts/standard"
      elsif action_name == "iphone_with_html_response_type_without_layout"
        "respond_to/layouts/missing"
      end
    end
end

class MimeControllerTest < ActionController::TestCase
  tests RespondToController

  def setup
    ActionController::Base.use_accept_header = true
    @request.host = "www.example.com"
  end

  def teardown
    ActionController::Base.use_accept_header = false
  end

  def test_html
    @request.accept = "text/html"
    get :js_or_html
    assert_equal 'HTML', @response.body

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_response 406
  end

  def test_all
    @request.accept = "*/*"
    get :js_or_html
    assert_equal 'HTML', @response.body # js is not part of all

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_equal 'XML', @response.body
  end

  def test_xml
    @request.accept = "application/xml"
    get :html_xml_or_rss
    assert_equal 'XML', @response.body
  end

  def test_js_or_html
    @request.accept = "text/javascript, text/html"
    get :js_or_html
    assert_equal 'JS', @response.body

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_response 406
  end

  def test_json_or_yaml
    get :json_or_yaml
    assert_equal 'JSON', @response.body

    get :json_or_yaml, :format => 'json'
    assert_equal 'JSON', @response.body

    get :json_or_yaml, :format => 'yaml'
    assert_equal 'YAML', @response.body

    { 'YAML' => %w(text/yaml),
      'JSON' => %w(application/json text/x-json)
    }.each do |body, content_types|
      content_types.each do |content_type|
        @request.accept = content_type
        get :json_or_yaml
        assert_equal body, @response.body
      end
    end
  end

  def test_js_or_anything
    @request.accept = "text/javascript, */*"
    get :js_or_html
    assert_equal 'JS', @response.body

    get :html_or_xml
    assert_equal 'HTML', @response.body

    get :just_xml
    assert_equal 'XML', @response.body
  end

  def test_using_defaults
    @request.accept = "*/*"
    get :using_defaults
    assert_equal "text/html", @response.content_type
    assert_equal 'Hello world!', @response.body

    @request.accept = "text/javascript"
    get :using_defaults
    assert_equal "text/javascript", @response.content_type
    assert_equal '$("body").visualEffect("highlight");', @response.body

    @request.accept = "application/xml"
    get :using_defaults
    assert_equal "application/xml", @response.content_type
    assert_equal "<p>Hello world!</p>\n", @response.body
  end

  def test_using_defaults_with_type_list
    @request.accept = "*/*"
    get :using_defaults_with_type_list
    assert_equal "text/html", @response.content_type
    assert_equal 'Hello world!', @response.body

    @request.accept = "text/javascript"
    get :using_defaults_with_type_list
    assert_equal "text/javascript", @response.content_type
    assert_equal '$("body").visualEffect("highlight");', @response.body

    @request.accept = "application/xml"
    get :using_defaults_with_type_list
    assert_equal "application/xml", @response.content_type
    assert_equal "<p>Hello world!</p>\n", @response.body
  end

  def test_with_atom_content_type
    @request.env["CONTENT_TYPE"] = "application/atom+xml"
    get :made_for_content_type
    assert_equal "ATOM", @response.body
  end

  def test_with_rss_content_type
    @request.env["CONTENT_TYPE"] = "application/rss+xml"
    get :made_for_content_type
    assert_equal "RSS", @response.body
  end

  def test_synonyms
    @request.accept = "application/javascript"
    get :js_or_html
    assert_equal 'JS', @response.body

    @request.accept = "application/x-xml"
    get :html_xml_or_rss
    assert_equal "XML", @response.body
  end

  def test_custom_types
    @request.accept = "application/crazy-xml"
    get :custom_type_handling
    assert_equal "application/crazy-xml", @response.content_type
    assert_equal 'Crazy XML', @response.body

    @request.accept = "text/html"
    get :custom_type_handling
    assert_equal "text/html", @response.content_type
    assert_equal 'HTML', @response.body
  end

  def test_xhtml_alias
    @request.accept = "application/xhtml+xml,application/xml"
    get :html_or_xml
    assert_equal 'HTML', @response.body
  end

  def test_firefox_simulation
    @request.accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"
    get :html_or_xml
    assert_equal 'HTML', @response.body
  end

  def test_handle_any
    @request.accept = "*/*"
    get :handle_any
    assert_equal 'HTML', @response.body

    @request.accept = "text/javascript"
    get :handle_any
    assert_equal 'Either JS or XML', @response.body

    @request.accept = "text/xml"
    get :handle_any
    assert_equal 'Either JS or XML', @response.body
  end

  def test_handle_any_any
    @request.accept = "*/*"
    get :handle_any_any
    assert_equal 'HTML', @response.body
  end

  def test_handle_any_any_parameter_format
    get :handle_any_any, {:format=>'html'}
    assert_equal 'HTML', @response.body
  end

  def test_handle_any_any_explicit_html
    @request.accept = "text/html"
    get :handle_any_any
    assert_equal 'HTML', @response.body
  end

  def test_handle_any_any_javascript
    @request.accept = "text/javascript"
    get :handle_any_any
    assert_equal 'Whatever you ask for, I got it', @response.body
  end

  def test_handle_any_any_xml
    @request.accept = "text/xml"
    get :handle_any_any
    assert_equal 'Whatever you ask for, I got it', @response.body
  end

  def test_rjs_type_skips_layout
    @request.accept = "text/javascript"
    get :all_types_with_layout
    assert_equal 'RJS for all_types_with_layout', @response.body
  end

  def test_html_type_with_layout
    @request.accept = "text/html"
    get :all_types_with_layout
    assert_equal '<html><div id="html">HTML for all_types_with_layout</div></html>', @response.body
  end

  def test_xhr
    xhr :get, :js_or_html
    assert_equal 'JS', @response.body

    xhr :get, :using_defaults
    assert_equal '$("body").visualEffect("highlight");', @response.body
  end

  def test_custom_constant
    get :custom_constant_handling, :format => "mobile"
    assert_equal "text/x-mobile", @response.content_type
    assert_equal "Mobile", @response.body
  end

  def test_custom_constant_handling_without_block
    get :custom_constant_handling_without_block, :format => "mobile"
    assert_equal "text/x-mobile", @response.content_type
    assert_equal "Mobile", @response.body
  end

  def test_forced_format
    get :html_xml_or_rss
    assert_equal "HTML", @response.body

    get :html_xml_or_rss, :format => "html"
    assert_equal "HTML", @response.body

    get :html_xml_or_rss, :format => "xml"
    assert_equal "XML", @response.body

    get :html_xml_or_rss, :format => "rss"
    assert_equal "RSS", @response.body
  end

  def test_internally_forced_format
    get :forced_xml
    assert_equal "XML", @response.body

    get :forced_xml, :format => "html"
    assert_equal "XML", @response.body
  end

  def test_extension_synonyms
    get :html_xml_or_rss, :format => "xhtml"
    assert_equal "HTML", @response.body
  end

  def test_render_action_for_html
    @controller.instance_eval do
      def render(*args)
        unless args.empty?
          @action = args.first[:action]
        end
        response.body = "#{@action} - #{@template.template_format}"
      end
    end

    get :using_defaults
    assert_equal "using_defaults - html", @response.body

    get :using_defaults, :format => "xml"
    assert_equal "using_defaults - xml", @response.body
  end

  def test_format_with_custom_response_type
    get :iphone_with_html_response_type
    assert_equal '<html><div id="html">Hello future from Firefox!</div></html>', @response.body

    get :iphone_with_html_response_type, :format => "iphone"
    assert_equal "text/html", @response.content_type
    assert_equal '<html><div id="iphone">Hello iPhone future from iPhone!</div></html>', @response.body
  end

  def test_format_with_custom_response_type_and_request_headers
    @request.accept = "text/iphone"
    get :iphone_with_html_response_type
    assert_equal '<html><div id="iphone">Hello iPhone future from iPhone!</div></html>', @response.body
    assert_equal "text/html", @response.content_type
  end

  def test_format_with_custom_response_type_and_request_headers_with_only_one_layout_present
    get :iphone_with_html_response_type_without_layout
    assert_equal '<html><div id="html_missing">Hello future from Firefox!</div></html>', @response.body

    @request.accept = "text/iphone"
    assert_raises(ActionView::MissingTemplate) { get :iphone_with_html_response_type_without_layout }
  end
end

class AbstractPostController < ActionController::Base
  self.view_paths = File.dirname(__FILE__) + "/../fixtures/post_test/"
end

# For testing layouts which are set automatically
class PostController < AbstractPostController
  around_filter :with_iphone

  def index
    respond_to do |type|
      type.html
      type.iphone
    end
  end

  protected
    def with_iphone
      Mime::Type.register_alias("text/html", :iphone)
      request.format = "iphone" if request.env["HTTP_ACCEPT"] == "text/iphone"
      yield
    ensure
      Mime.module_eval { remove_const :IPHONE if const_defined?(:IPHONE) }
    end
end

class SuperPostController < PostController
  def index
    respond_to do |type|
      type.html
      type.iphone
    end
  end
end

class MimeControllerLayoutsTest < ActionController::TestCase
  tests PostController

  def setup
    @request.host = "www.example.com"
  end

  def test_missing_layout_renders_properly
    get :index
    assert_equal '<html><div id="html">Hello Firefox</div></html>', @response.body

    @request.accept = "text/iphone"
    get :index
    assert_equal 'Hello iPhone', @response.body
  end

  def test_format_with_inherited_layouts
    @controller = SuperPostController.new

    get :index
    assert_equal 'Super Firefox', @response.body

    @request.accept = "text/iphone"
    get :index
    assert_equal '<html><div id="super_iphone">Super iPhone</div></html>', @response.body
  end
end
