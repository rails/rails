require 'abstract_unit'
require 'controller/fake_models'
require 'active_support/core_ext/hash/conversions'

class StarStarMimeController < ActionController::Base
  layout nil

  def index
    render
  end
end

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

  def json_xml_or_html
    respond_to do |type|
      type.json { render :text => 'JSON' }
      type.xml { render :xml => 'XML' }
      type.html { render :text => 'HTML' }
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
      type.xml
    end
  end

  def using_defaults_with_type_list
    respond_to(:html, :xml)
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
    respond_to do |type|
      type.html   { render :text => "HTML"   }
      type.mobile { render :text => "Mobile" }
    end
  end

  def custom_constant_handling_without_block
    respond_to do |type|
      type.html   { render :text => "HTML"   }
      type.mobile
    end
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
    end
  end

  def iphone_with_html_response_type
    request.format = :iphone if request.env["HTTP_ACCEPT"] == "text/iphone"

    respond_to do |type|
      type.html   { @type = "Firefox" }
      type.iphone { @type = "iPhone"  }
    end
  end

  def iphone_with_html_response_type_without_layout
    request.format = "iphone" if request.env["HTTP_ACCEPT"] == "text/iphone"

    respond_to do |type|
      type.html   { @type = "Firefox"; render :action => "iphone_with_html_response_type" }
      type.iphone { @type = "iPhone" ; render :action => "iphone_with_html_response_type" }
    end
  end

  protected
    def set_layout
      case action_name
        when "all_types_with_layout", "iphone_with_html_response_type"
          "respond_to/layouts/standard"
        when "iphone_with_html_response_type_without_layout"
          "respond_to/layouts/missing"
      end
    end
end

class StarStarMimeControllerTest < ActionController::TestCase
  tests StarStarMimeController

  def test_javascript_with_format
    @request.accept = "text/javascript"
    get :index, :format => 'js'
    assert_match "function addition(a,b){ return a+b; }", @response.body
  end

  def test_javascript_with_no_format
    @request.accept = "text/javascript"
    get :index
    assert_match "function addition(a,b){ return a+b; }", @response.body
  end

  def test_javascript_with_no_format_only_star_star
    @request.accept = "*/*"
    get :index
    assert_match "function addition(a,b){ return a+b; }", @response.body
  end

end

class RespondToControllerTest < ActionController::TestCase
  tests RespondToController

  def setup
    super
    @request.host = "www.example.com"
    Mime::Type.register_alias("text/html", :iphone)
    Mime::Type.register("text/x-mobile", :mobile)
  end

  def teardown
    super
    Mime::Type.unregister(:iphone)
    Mime::Type.unregister(:mobile)
  end

  def test_html
    @request.accept = "text/html"
    get :js_or_html
    assert_equal 'HTML', @response.body

    get :html_or_xml
    assert_equal 'HTML', @response.body

    assert_raises(ActionController::UnknownFormat) do
      get :just_xml
    end
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
    xhr :get, :js_or_html
    assert_equal 'JS', @response.body

    @request.accept = "text/javascript, text/html"
    xhr :get, :html_or_xml
    assert_equal 'HTML', @response.body

    @request.accept = "text/javascript, text/html"

    assert_raises(ActionController::UnknownFormat) do
      xhr :get, :just_xml
    end
  end

  def test_json_or_yaml_with_leading_star_star
    @request.accept = "*/*, application/json"
    get :json_xml_or_html
    assert_equal 'HTML', @response.body

    @request.accept = "*/* , application/json"
    get :json_xml_or_html
    assert_equal 'HTML', @response.body
  end

  def test_json_or_yaml
    xhr :get, :json_or_yaml
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
    xhr :get, :js_or_html
    assert_equal 'JS', @response.body

    xhr :get, :html_or_xml
    assert_equal 'HTML', @response.body

    xhr :get, :just_xml
    assert_equal 'XML', @response.body
  end

  def test_using_defaults
    @request.accept = "*/*"
    get :using_defaults
    assert_equal "text/html", @response.content_type
    assert_equal 'Hello world!', @response.body

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

    @request.accept = "application/xml"
    get :using_defaults_with_type_list
    assert_equal "application/xml", @response.content_type
    assert_equal "<p>Hello world!</p>\n", @response.body
  end

  def test_with_atom_content_type
    @request.accept = ""
    @request.env["CONTENT_TYPE"] = "application/atom+xml"
    xhr :get, :made_for_content_type
    assert_equal "ATOM", @response.body
  end

  def test_with_rss_content_type
    @request.accept = ""
    @request.env["CONTENT_TYPE"] = "application/rss+xml"
    xhr :get, :made_for_content_type
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

  def test_browser_check_with_any_any
    @request.accept = "application/json, application/xml"
    get :json_xml_or_html
    assert_equal 'JSON', @response.body

    @request.accept = "application/json, application/xml, */*"
    get :json_xml_or_html
    assert_equal 'HTML', @response.body
  end

  def test_html_type_with_layout
    @request.accept = "text/html"
    get :all_types_with_layout
    assert_equal '<html><div id="html">HTML for all_types_with_layout</div></html>', @response.body
  end

  def test_xhr
    xhr :get, :js_or_html
    assert_equal 'JS', @response.body
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

  def test_invalid_format
    assert_raises(ActionController::UnknownFormat) do
      get :using_defaults, :format => "invalidformat"
    end
  end
end

class RespondWithController < ActionController::Base
  respond_to :html, :json, :touch
  respond_to :xml, :except => :using_resource_with_block
  respond_to :js,  :only => [ :using_resource_with_block, :using_resource, 'using_hash_resource' ]

  def using_resource
    respond_with(resource)
  end

  def using_hash_resource
    respond_with({:result => resource})
  end

  def using_resource_with_block
    respond_with(resource) do |format|
      format.csv { render :text => "CSV" }
    end
  end

  def using_resource_with_overwrite_block
    respond_with(resource) do |format|
      format.html { render :text => "HTML" }
    end
  end

  def using_resource_with_collection
    respond_with([resource, Customer.new("jamis", 9)])
  end

  def using_resource_with_parent
    respond_with(Quiz::Store.new("developer?", 11), Customer.new("david", 13))
  end

  def using_resource_with_status_and_location
    respond_with(resource, :location => "http://test.host/", :status => :created)
  end

  def using_invalid_resource_with_template
    respond_with(resource)
  end

  def using_options_with_template
    @customer = resource
    respond_with(@customer, :status => 123, :location => "http://test.host/")
  end

  def using_resource_with_responder
    responder = proc { |c, r, o| c.render :text => "Resource name is #{r.first.name}" }
    respond_with(resource, :responder => responder)
  end

  def using_resource_with_action
    respond_with(resource, :action => :foo) do |format|
      format.html { raise ActionView::MissingTemplate.new([], "bar", ["foo"], {}, false) }
    end
  end

  def using_responder_with_respond
    responder = Class.new(ActionController::Responder) do
      def respond; @controller.render :text => "respond #{format}"; end
    end
    respond_with(resource, :responder => responder)
  end

protected

  def resource
    Customer.new("david", request.delete? ? nil : 13)
  end
end

class InheritedRespondWithController < RespondWithController
  clear_respond_to
  respond_to :xml, :json

  def index
    respond_with(resource) do |format|
      format.json { render :text => "JSON" }
    end
  end
end

class RenderJsonRespondWithController < RespondWithController
  clear_respond_to
  respond_to :json

  def index
    respond_with(resource) do |format|
      format.json { render :json => RenderJsonTestException.new('boom') }
    end
  end

  def create
    resource = ValidatedCustomer.new(params[:name], 1)
    respond_with(resource) do |format|
      format.json do
        if resource.errors.empty?
          render :json => { :valid => true }
        else
          render :json => { :valid => false }
        end
      end
    end
  end
end

class EmptyRespondWithController < ActionController::Base
  def index
    respond_with(Customer.new("david", 13))
  end
end

class RespondWithControllerTest < ActionController::TestCase
  tests RespondWithController

  def setup
    super
    @request.host = "www.example.com"
    Mime::Type.register_alias('text/html', :iphone)
    Mime::Type.register_alias('text/html', :touch)
    Mime::Type.register('text/x-mobile', :mobile)
  end

  def teardown
    super
    Mime::Type.unregister(:iphone)
    Mime::Type.unregister(:touch)
    Mime::Type.unregister(:mobile)
  end

  def test_using_resource
    @request.accept = "application/xml"
    get :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal "<name>david</name>", @response.body

    @request.accept = "application/json"
    assert_raise ActionView::MissingTemplate do
      get :using_resource
    end
  end

  def test_using_resource_with_js_simply_tries_to_render_the_template
    @request.accept = "text/javascript"
    get :using_resource
    assert_equal "text/javascript", @response.content_type
    assert_equal "alert(\"Hi\");", @response.body
  end

  def test_using_hash_resource_with_js_raises_an_error_if_template_cant_be_found
    @request.accept = "text/javascript"
    assert_raise ActionView::MissingTemplate do
      get :using_hash_resource
    end
  end

  def test_using_hash_resource
    @request.accept = "application/xml"
    get :using_hash_resource
    assert_equal "application/xml", @response.content_type
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n  <name>david</name>\n</hash>\n", @response.body

    @request.accept = "application/json"
    get :using_hash_resource
    assert_equal "application/json", @response.content_type
    assert @response.body.include?("result")
    assert @response.body.include?('"name":"david"')
    assert @response.body.include?('"id":13')
  end

  def test_using_hash_resource_with_post
    @request.accept = "application/json"
    assert_raise ArgumentError, "Nil location provided. Can't build URI." do
      post :using_hash_resource
    end
  end

  def test_using_resource_with_block
    @request.accept = "*/*"
    get :using_resource_with_block
    assert_equal "text/html", @response.content_type
    assert_equal 'Hello world!', @response.body

    @request.accept = "text/csv"
    get :using_resource_with_block
    assert_equal "text/csv", @response.content_type
    assert_equal "CSV", @response.body

    @request.accept = "application/xml"
    get :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal "<name>david</name>", @response.body
  end

  def test_using_resource_with_overwrite_block
    get :using_resource_with_overwrite_block
    assert_equal "text/html", @response.content_type
    assert_equal "HTML", @response.body
  end

  def test_not_acceptable
    @request.accept = "application/xml"
    assert_raises(ActionController::UnknownFormat) do
      get :using_resource_with_block
    end

    @request.accept = "text/javascript"
    assert_raises(ActionController::UnknownFormat) do
      get :using_resource_with_overwrite_block
    end
  end

  def test_using_resource_for_post_with_html_redirects_on_success
    with_test_route_set do
      post :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 302, @response.status
      assert_equal "http://www.example.com/customers/13", @response.location
      assert @response.redirect?
    end
  end

  def test_using_resource_for_post_with_html_rerender_on_failure
    with_test_route_set do
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      post :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 200, @response.status
      assert_equal "New world!\n", @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_post_with_xml_yields_created_on_success
    with_test_route_set do
      @request.accept = "application/xml"
      post :using_resource
      assert_equal "application/xml", @response.content_type
      assert_equal 201, @response.status
      assert_equal "<name>david</name>", @response.body
      assert_equal "http://www.example.com/customers/13", @response.location
    end
  end

  def test_using_resource_for_post_with_xml_yields_unprocessable_entity_on_failure
    with_test_route_set do
      @request.accept = "application/xml"
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      post :using_resource
      assert_equal "application/xml", @response.content_type
      assert_equal 422, @response.status
      assert_equal errors.to_xml, @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_post_with_json_yields_unprocessable_entity_on_failure
    with_test_route_set do
      @request.accept = "application/json"
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      post :using_resource
      assert_equal "application/json", @response.content_type
      assert_equal 422, @response.status
      errors = {:errors => errors}
      assert_equal errors.to_json, @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_patch_with_html_redirects_on_success
    with_test_route_set do
      patch :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 302, @response.status
      assert_equal "http://www.example.com/customers/13", @response.location
      assert @response.redirect?
    end
  end

  def test_using_resource_for_patch_with_html_rerender_on_failure
    with_test_route_set do
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      patch :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 200, @response.status
      assert_equal "Edit world!\n", @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_patch_with_html_rerender_on_failure_even_on_method_override
    with_test_route_set do
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      @request.env["rack.methodoverride.original_method"] = "POST"
      patch :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 200, @response.status
      assert_equal "Edit world!\n", @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_put_with_html_redirects_on_success
    with_test_route_set do
      put :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 302, @response.status
      assert_equal "http://www.example.com/customers/13", @response.location
      assert @response.redirect?
    end
  end

  def test_using_resource_for_put_with_html_rerender_on_failure
    with_test_route_set do
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      put :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 200, @response.status
      assert_equal "Edit world!\n", @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_put_with_html_rerender_on_failure_even_on_method_override
    with_test_route_set do
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      @request.env["rack.methodoverride.original_method"] = "POST"
      put :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 200, @response.status
      assert_equal "Edit world!\n", @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_for_put_with_xml_yields_no_content_on_success
    @request.accept = "application/xml"
    put :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 204, @response.status
    assert_equal "", @response.body
  end

  def test_using_resource_for_put_with_json_yields_no_content_on_success
    Customer.any_instance.stubs(:to_json).returns('{"name": "David"}')
    @request.accept = "application/json"
    put :using_resource
    assert_equal "application/json", @response.content_type
    assert_equal 204, @response.status
    assert_equal "", @response.body
  end

  def test_using_resource_for_put_with_xml_yields_unprocessable_entity_on_failure
    @request.accept = "application/xml"
    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    put :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 422, @response.status
    assert_equal errors.to_xml, @response.body
    assert_nil @response.location
  end

  def test_using_resource_for_put_with_json_yields_unprocessable_entity_on_failure
    @request.accept = "application/json"
    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)
    put :using_resource
    assert_equal "application/json", @response.content_type
    assert_equal 422, @response.status
    errors = {:errors => errors}
    assert_equal errors.to_json, @response.body
    assert_nil @response.location
  end

  def test_using_resource_for_delete_with_html_redirects_on_success
    with_test_route_set do
      Customer.any_instance.stubs(:destroyed?).returns(true)
      delete :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 302, @response.status
      assert_equal "http://www.example.com/customers", @response.location
    end
  end

  def test_using_resource_for_delete_with_xml_yields_no_content_on_success
    Customer.any_instance.stubs(:destroyed?).returns(true)
    @request.accept = "application/xml"
    delete :using_resource
    assert_equal "application/xml", @response.content_type
    assert_equal 204, @response.status
    assert_equal "", @response.body
  end

  def test_using_resource_for_delete_with_json_yields_no_content_on_success
    Customer.any_instance.stubs(:to_json).returns('{"name": "David"}')
    Customer.any_instance.stubs(:destroyed?).returns(true)
    @request.accept = "application/json"
    delete :using_resource
    assert_equal "application/json", @response.content_type
    assert_equal 204, @response.status
    assert_equal "", @response.body
  end

  def test_using_resource_for_delete_with_html_redirects_on_failure
    with_test_route_set do
      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      Customer.any_instance.stubs(:destroyed?).returns(false)
      delete :using_resource
      assert_equal "text/html", @response.content_type
      assert_equal 302, @response.status
      assert_equal "http://www.example.com/customers", @response.location
    end
  end

  def test_using_resource_with_parent_for_get
    @request.accept = "application/xml"
    get :using_resource_with_parent
    assert_equal "application/xml", @response.content_type
    assert_equal 200, @response.status
    assert_equal "<name>david</name>", @response.body
  end

  def test_using_resource_with_parent_for_post
    with_test_route_set do
      @request.accept = "application/xml"

      post :using_resource_with_parent
      assert_equal "application/xml", @response.content_type
      assert_equal 201, @response.status
      assert_equal "<name>david</name>", @response.body
      assert_equal "http://www.example.com/quiz_stores/11/customers/13", @response.location

      errors = { :name => :invalid }
      Customer.any_instance.stubs(:errors).returns(errors)
      post :using_resource
      assert_equal "application/xml", @response.content_type
      assert_equal 422, @response.status
      assert_equal errors.to_xml, @response.body
      assert_nil @response.location
    end
  end

  def test_using_resource_with_collection
    @request.accept = "application/xml"
    get :using_resource_with_collection
    assert_equal "application/xml", @response.content_type
    assert_equal 200, @response.status
    assert_match(/<name>david<\/name>/, @response.body)
    assert_match(/<name>jamis<\/name>/, @response.body)
  end

  def test_using_resource_with_action
    @controller.instance_eval do
      def render(params={})
        self.response_body = "#{params[:action]} - #{formats}"
      end
    end

    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)

    post :using_resource_with_action
    assert_equal "foo - #{[:html].to_s}", @controller.response.body
  end

  def test_respond_as_responder_entry_point
    @request.accept = "text/html"
    get :using_responder_with_respond
    assert_equal "respond html", @response.body

    @request.accept = "application/xml"
    get :using_responder_with_respond
    assert_equal "respond xml", @response.body
  end

  def test_clear_respond_to
    @controller = InheritedRespondWithController.new
    @request.accept = "text/html"
    assert_raises(ActionController::UnknownFormat) do
      get :index
    end
  end

  def test_first_in_respond_to_has_higher_priority
    @controller = InheritedRespondWithController.new
    @request.accept = "*/*"
    get :index
    assert_equal "application/xml", @response.content_type
    assert_equal "<name>david</name>", @response.body
  end

  def test_block_inside_respond_with_is_rendered
    @controller = InheritedRespondWithController.new
    @request.accept = "application/json"
    get :index
    assert_equal "JSON", @response.body
  end

  def test_render_json_object_responds_to_str_still_produce_json
    @controller = RenderJsonRespondWithController.new
    @request.accept = "application/json"
    get :index, :format => :json
    assert_match(/"message":"boom"/, @response.body)
    assert_match(/"error":"RenderJsonTestException"/, @response.body)
  end

  def test_api_response_with_valid_resource_respect_override_block
    @controller = RenderJsonRespondWithController.new
    post :create, :name => "sikachu", :format => :json
    assert_equal '{"valid":true}', @response.body
  end

  def test_api_response_with_invalid_resource_respect_override_block
    @controller = RenderJsonRespondWithController.new
    post :create, :name => "david", :format => :json
    assert_equal '{"valid":false}', @response.body
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

  def test_using_resource_with_status_and_location_with_invalid_resource
    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)

    @request.accept = "text/xml"

    post :using_resource_with_status_and_location
    assert_equal errors.to_xml, @response.body
    assert_equal 422, @response.status
    assert_equal nil, @response.location

    put :using_resource_with_status_and_location
    assert_equal errors.to_xml, @response.body
    assert_equal 422, @response.status
    assert_equal nil, @response.location
  end

  def test_using_invalid_resource_with_template
    errors = { :name => :invalid }
    Customer.any_instance.stubs(:errors).returns(errors)

    @request.accept = "text/xml"

    post :using_invalid_resource_with_template
    assert_equal errors.to_xml, @response.body
    assert_equal 422, @response.status
    assert_equal nil, @response.location

    put :using_invalid_resource_with_template
    assert_equal errors.to_xml, @response.body
    assert_equal 422, @response.status
    assert_equal nil, @response.location
  end

  def test_using_options_with_template
    @request.accept = "text/xml"

    post :using_options_with_template
    assert_equal "<customer-name>david</customer-name>", @response.body
    assert_equal 123, @response.status
    assert_equal "http://test.host/", @response.location

    put :using_options_with_template
    assert_equal "<customer-name>david</customer-name>", @response.body
    assert_equal 123, @response.status
    assert_equal "http://test.host/", @response.location
  end

  def test_using_resource_with_responder
    get :using_resource_with_responder
    assert_equal "Resource name is david", @response.body
  end

  def test_using_resource_with_set_responder
    RespondWithController.responder = proc { |c, r, o| c.render :text => "Resource name is #{r.first.name}" }
    get :using_resource
    assert_equal "Resource name is david", @response.body
  ensure
    RespondWithController.responder = ActionController::Responder
  end

  def test_error_is_raised_if_no_respond_to_is_declared_and_respond_with_is_called
    @controller = EmptyRespondWithController.new
    @request.accept = "*/*"
    assert_raise RuntimeError do
      get :index
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do
          resources :customers
          resources :quiz_stores do
            resources :customers
          end
          get ":controller/:action"
        end
        yield
      end
    end
end

class AbstractPostController < ActionController::Base
  self.view_paths = File.dirname(__FILE__) + "/../fixtures/post_test/"
end

# For testing layouts which are set automatically
class PostController < AbstractPostController
  around_action :with_iphone

  def index
    respond_to(:html, :iphone, :js)
  end

protected

  def with_iphone
    request.format = "iphone" if request.env["HTTP_ACCEPT"] == "text/iphone"
    yield
  end
end

class SuperPostController < PostController
end

class MimeControllerLayoutsTest < ActionController::TestCase
  tests PostController

  def setup
    super
    @request.host = "www.example.com"
    Mime::Type.register_alias("text/html", :iphone)
  end

  def teardown
    super
    Mime::Type.unregister(:iphone)
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

  def test_non_navigational_format_with_no_template_fallbacks_to_html_template_with_no_layout
    get :index, :format => :js
    assert_equal "Hello Firefox", @response.body
  end
end

class FlashResponder < ActionController::Responder
  def initialize(controller, resources, options={})
    super
  end

  def to_html
    controller.flash[:notice] = 'Success'
    super
  end
end

class FlashResponderController < ActionController::Base
  self.responder = FlashResponder
  respond_to :html

  def index
    respond_with Object.new do |format|
      format.html { render :text => 'HTML' }
    end
  end
end

class FlashResponderControllerTest < ActionController::TestCase
  tests FlashResponderController

  def test_respond_with_block_executed
    get :index
    assert_equal 'HTML', @response.body
  end

  def test_flash_responder_executed
    get :index
    assert_equal 'Success', flash[:notice]
  end
end
