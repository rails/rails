require 'abstract_unit'
require 'controller/fake_models'

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
    Mime::SET.delete(:mobile)
    Mime.module_eval { remove_const :MOBILE if const_defined?(:MOBILE) }
  end

  def custom_constant_handling_without_block
    Mime::Type.register("text/x-mobile", :mobile)

    respond_to do |type|
      type.html   { render :text => "HTML"   }
      type.mobile
    end

  ensure
    Mime::SET.delete(:mobile)
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
    Mime::SET.delete(:iphone)
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
    Mime::SET.delete(:iphone)
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

class RespondToControllerTest < ActionController::TestCase
  tests RespondToController

  def setup
    super
    ActionController::Base.use_accept_header = true
    @request.host = "www.example.com"
  end

  def teardown
    super
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
        @action = args.first[:action] unless args.empty?
        @action ||= action_name

        response.body = "#{@action} - #{formats}"
      end
    end

    get :using_defaults
    assert_equal "using_defaults - #{[:html].to_s}", @response.body

    get :using_defaults, :format => "xml"
    assert_equal "using_defaults - #{[:xml].to_s}", @response.body
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
end

class RespondWithController < ActionController::Base
  respond_to :html, :json
  respond_to :xml, :except => :using_defaults
  respond_to :js,  :only => [ :using_defaults, :using_resource ]

  def using_defaults
    respond_to do |format|
      format.csv { render :text => "CSV" }
    end
  end

  def using_defaults_with_type_list
    respond_to(:js, :xml)
  end

  def default_overwritten
    respond_to do |format|
      format.html { render :text => "HTML" }
    end
  end

  def using_resource
    respond_with(Customer.new("david", 13))
  end

  def using_resource_with_parent
    respond_with([Quiz::Store.new("developer?", 11), Customer.new("david", 13)])
  end

  def using_resource_with_status_and_location
    respond_with(Customer.new("david", 13), :location => "http://test.host/", :status => :created)
  end

  def using_resource_with_responder
    responder = proc { |c, r, o| c.render :text => "Resource name is #{r.name}" }
    respond_with(Customer.new("david", 13), :responder => responder)
  end

protected

  def _render_js(js, options)
    self.content_type ||= Mime::JS
    self.response_body = js.respond_to?(:to_js) ? js.to_js : js
  end
end

class InheritedRespondWithController < RespondWithController
  clear_respond_to
  respond_to :xml, :json

  def index
    respond_with(Customer.new("david", 13)) do |format|
      format.json { render :text => "JSON" }
    end
  end
end

class RespondWithControllerTest < ActionController::TestCase
  tests RespondWithController

  def setup
    super
    ActionController::Base.use_accept_header = true
    @request.host = "www.example.com"

    ActionController::Routing::Routes.draw do |map|
      map.resources :customers
      map.resources :quiz_stores, :has_many => :customers
    end
  end

  def teardown
    super
    ActionController::Base.use_accept_header = false
  end

  def test_using_defaults
    @request.accept = "*/*"
    get :using_defaults
    assert_equal "text/html", @response.content_type
    assert_equal 'Hello world!', @response.body

    @request.accept = "text/csv"
    get :using_defaults
    assert_equal "text/csv", @response.content_type
    assert_equal "CSV", @response.body

    @request.accept = "text/javascript"
    get :using_defaults
    assert_equal "text/javascript", @response.content_type
    assert_equal '$("body").visualEffect("highlight");', @response.body
  end

  def test_using_defaults_with_type_list
    @request.accept = "*/*"
    get :using_defaults_with_type_list
    assert_equal "text/javascript", @response.content_type
    assert_equal '$("body").visualEffect("highlight");', @response.body

    @request.accept = "application/xml"
    get :using_defaults_with_type_list
    assert_equal "application/xml", @response.content_type
    assert_equal "<p>Hello world!</p>\n", @response.body
  end

  def test_default_overwritten
    get :default_overwritten
    assert_equal "text/html", @response.content_type
    assert_equal "HTML", @response.body
  end

  def test_using_resource
    @request.accept = "text/javascript"
    get :using_resource
    assert_equal "text/javascript", @response.content_type
    assert_equal '$("body").visualEffect("highlight");', @response.body

    @request.accept = "application/xml"
    get :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal "XML", @response.body

    @request.accept = "application/json"
    assert_raise ActionView::MissingTemplate do
      get :using_resource
    end
  end

  def test_using_resource_for_post_with_html
    post :using_resource
    assert_equal "text/html", @response.content_type
    assert_equal 302, @response.status
    assert_equal "http://www.example.com/customers/13", @response.location
    assert @response.redirect?

    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    post :using_resource
    assert_equal "text/html", @response.content_type
    assert_equal 200, @response.status
    assert_equal "New world!\n", @response.body
    assert_nil @response.location
  end

  def test_using_resource_for_post_with_xml
    @request.accept = "application/xml"

    post :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 201, @response.status
    assert_equal "XML", @response.body
    assert_equal "http://www.example.com/customers/13", @response.location

    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    post :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 422, @response.status
    assert_equal errors.to_xml, @response.body
    assert_nil @response.location
  end

  def test_using_resource_for_put_with_html
    put :using_resource
    assert_equal "text/html", @response.content_type
    assert_equal 302, @response.status
    assert_equal "http://www.example.com/customers/13", @response.location
    assert @response.redirect?

    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    put :using_resource
    assert_equal "text/html", @response.content_type
    assert_equal 200, @response.status
    assert_equal "Edit world!\n", @response.body
    assert_nil @response.location
  end

  def test_using_resource_for_put_with_xml
    @request.accept = "application/xml"

    put :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 200, @response.status
    assert_equal " ", @response.body

    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    put :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 422, @response.status
    assert_equal errors.to_xml, @response.body
    assert_nil @response.location
  end

  def test_using_resource_for_delete_with_html
    Customer.any_instance.stubs(:destroyed?).returns(true)
    delete :using_resource
    assert_equal "text/html", @response.content_type
    assert_equal 302, @response.status
    assert_equal "http://www.example.com/customers", @response.location
  end

  def test_using_resource_for_delete_with_xml
    Customer.any_instance.stubs(:destroyed?).returns(true)
    @request.accept = "application/xml"
    delete :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 200, @response.status
    assert_equal " ", @response.body
  end

  def test_using_resource_with_parent_for_get
    @request.accept = "application/xml"
    get :using_resource_with_parent
    assert_equal "application/xml", @response.content_type
    assert_equal 200, @response.status
    assert_equal "XML", @response.body
  end

  def test_using_resource_with_parent_for_post
    @request.accept = "application/xml"

    post :using_resource_with_parent
    assert_equal "application/xml", @response.content_type
    assert_equal 201, @response.status
    assert_equal "XML", @response.body
    assert_equal "http://www.example.com/quiz_stores/11/customers/13", @response.location

    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    post :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 422, @response.status
    assert_equal errors.to_xml, @response.body
    assert_nil @response.location
  end

  def test_clear_respond_to
    @controller = InheritedRespondWithController.new
    @request.accept = "text/html"
    get :index
    assert_equal 406, @response.status
  end

  def test_first_in_respond_to_has_higher_priority
    @controller = InheritedRespondWithController.new
    @request.accept = "*/*"
    get :index
    assert_equal "application/xml", @response.content_type
    assert_equal "XML", @response.body
  end

  def test_no_double_render_is_raised
    @request.accept = "text/html"
    assert_raise ActionView::MissingTemplate do
      get :using_resource
    end
  end

  def test_using_resource_with_status_and_location
    @request.accept = "text/html"
    post :using_resource_with_status_and_location
    assert @response.redirect?
    assert_equal "http://test.host/", @response.location

    @request.accept = "application/xml"
    get :using_resource_with_status_and_location
    assert_equal 201, @response.status
  end

  def test_using_resource_with_responder
    get :using_resource_with_responder
    assert_equal "Resource name is david", @response.body
  end

  def test_not_acceptable
    @request.accept = "application/xml"
    get :using_defaults
    assert_equal 406, @response.status

    @request.accept = "text/html"
    get :using_defaults_with_type_list
    assert_equal 406, @response.status

    @request.accept = "application/json"
    get :using_defaults_with_type_list
    assert_equal 406, @response.status

    @request.accept = "text/javascript"
    get :default_overwritten
    assert_equal 406, @response.status
  end
end

class AbstractPostController < ActionController::Base
  self.view_paths = File.dirname(__FILE__) + "/../fixtures/post_test/"
end

# For testing layouts which are set automatically
class PostController < AbstractPostController
  around_filter :with_iphone

  def index
    respond_to(:html, :iphone)
  end

protected

  def with_iphone
    Mime::Type.register_alias("text/html", :iphone)
    request.format = "iphone" if request.env["HTTP_ACCEPT"] == "text/iphone"
    yield
  ensure
    Mime::SET.delete(:iphone)
    Mime.module_eval { remove_const :IPHONE if const_defined?(:IPHONE) }
  end
end

class SuperPostController < PostController
end

class MimeControllerLayoutsTest < ActionController::TestCase
  tests PostController

  def setup
    super
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
    assert_equal '<html><div id="html">Super Firefox</div></html>', @response.body

    @request.accept = "text/iphone"
    get :index
    assert_equal '<html><div id="super_iphone">Super iPhone</div></html>', @response.body
  end
end
