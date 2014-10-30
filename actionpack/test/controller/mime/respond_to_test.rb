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

  def using_defaults_with_all
    respond_to do |type|
      type.html
      type.all{ render text: "ALL" }
    end
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

  def json_with_callback
    respond_to do |type|
      type.json { render :json => 'JS', :callback => 'alert' }
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

  def variant_with_implicit_rendering
  end

  def variant_with_format_and_custom_render
    request.variant = :mobile

    respond_to do |type|
      type.html { render text: "mobile" }
    end
  end

  def multiple_variants_for_format
    respond_to do |type|
      type.html do |html|
        html.tablet { render text: "tablet" }
        html.phone  { render text: "phone" }
      end
    end
  end

  def variant_plus_none_for_format
    respond_to do |format|
      format.html do |variant|
        variant.phone { render text: "phone" }
        variant.none
      end
    end
  end

  def variant_inline_syntax
    respond_to do |format|
      format.js         { render text: "js"    }
      format.html.none  { render text: "none"  }
      format.html.phone { render text: "phone" }
    end
  end

  def variant_inline_syntax_without_block
    respond_to do |format|
      format.js
      format.html.none
      format.html.phone
    end
  end

  def variant_any
    respond_to do |format|
      format.html do |variant|
        variant.any(:tablet, :phablet){ render text: "any" }
        variant.phone { render text: "phone" }
      end
    end
  end

  def variant_any_any
    respond_to do |format|
      format.html do |variant|
        variant.any   { render text: "any"   }
        variant.phone { render text: "phone" }
      end
    end
  end

  def variant_inline_any
    respond_to do |format|
      format.html.any(:tablet, :phablet){ render text: "any" }
      format.html.phone { render text: "phone" }
    end
  end

  def variant_inline_any_any
    respond_to do |format|
      format.html.phone { render text: "phone" }
      format.html.any   { render text: "any"   }
    end
  end

  def variant_any_implicit_render
    respond_to do |format|
      format.html.phone
      format.html.any(:tablet, :phablet)
    end
  end

  def variant_any_with_none
    respond_to do |format|
      format.html.any(:none, :phone){ render text: "none or phone" }
    end
  end

  def format_any_variant_any
    respond_to do |format|
      format.html { render text: "HTML" }
      format.any(:js, :xml) do |variant|
        variant.phone{ render text: "phone" }
        variant.any(:tablet, :phablet){ render text: "tablet" }
      end
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

class RespondToControllerTest < ActionController::TestCase
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

  def test_using_defaults_with_all
    @request.accept = "*/*"
    get :using_defaults_with_all
    assert_equal "HTML!", @response.body.strip

    @request.accept = "text/html"
    get :using_defaults_with_all
    assert_equal "HTML!", @response.body.strip

    @request.accept = "application/json"
    get :using_defaults_with_all
    assert_equal "ALL", @response.body
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

  def test_handle_any_any_unkown_format
    get :handle_any_any, { format: 'php' }
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

  def test_json_with_callback_sets_javascript_content_type
    @request.accept = 'application/json'
    get :json_with_callback
    assert_equal '/**/alert(JS)', @response.body
    assert_equal 'text/javascript', @response.content_type
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
    assert_equal "using_defaults - #{[:html]}", @response.body

    get :using_defaults, :format => "xml"
    assert_equal "using_defaults - #{[:xml]}", @response.body
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

  def test_invalid_variant
    @request.variant = :invalid
    assert_raises(ActionView::MissingTemplate) do
      get :variant_with_implicit_rendering
    end
  end

  def test_variant_not_set_regular_template_missing
    assert_raises(ActionView::MissingTemplate) do
      get :variant_with_implicit_rendering
    end
  end

  def test_variant_with_implicit_rendering
    @request.variant = :mobile
    get :variant_with_implicit_rendering
    assert_equal "text/html", @response.content_type
    assert_equal "mobile", @response.body
  end

  def test_variant_with_format_and_custom_render
    @request.variant = :phone
    get :variant_with_format_and_custom_render
    assert_equal "text/html", @response.content_type
    assert_equal "mobile", @response.body
  end

  def test_multiple_variants_for_format
    @request.variant = :tablet
    get :multiple_variants_for_format
    assert_equal "text/html", @response.content_type
    assert_equal "tablet", @response.body
  end

  def test_no_variant_in_variant_setup
    get :variant_plus_none_for_format
    assert_equal "text/html", @response.content_type
    assert_equal "none", @response.body
  end

  def test_variant_inline_syntax
    get :variant_inline_syntax, format: :js
    assert_equal "text/javascript", @response.content_type
    assert_equal "js", @response.body

    get :variant_inline_syntax
    assert_equal "text/html", @response.content_type
    assert_equal "none", @response.body

    @request.variant = :phone
    get :variant_inline_syntax
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body
  end

  def test_variant_inline_syntax_without_block
    @request.variant = :phone
    get :variant_inline_syntax_without_block
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body
  end

  def test_variant_any
    @request.variant = :phone
    get :variant_any
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body

    @request.variant = :tablet
    get :variant_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body

    @request.variant = :phablet
    get :variant_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body
  end

  def test_variant_any_any
    get :variant_any_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body

    @request.variant = :phone
    get :variant_any_any
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body

    @request.variant = :yolo
    get :variant_any_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body
  end

  def test_variant_inline_any
    @request.variant = :phone
    get :variant_any
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body

    @request.variant = :tablet
    get :variant_inline_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body

    @request.variant = :phablet
    get :variant_inline_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body
  end

  def test_variant_inline_any_any
    @request.variant = :phone
    get :variant_inline_any_any
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body

    @request.variant = :yolo
    get :variant_inline_any_any
    assert_equal "text/html", @response.content_type
    assert_equal "any", @response.body
  end

  def test_variant_any_implicit_render
    @request.variant = :tablet
    get :variant_any_implicit_render
    assert_equal "text/html", @response.content_type
    assert_equal "tablet", @response.body

    @request.variant = :phablet
    get :variant_any_implicit_render
    assert_equal "text/html", @response.content_type
    assert_equal "phablet", @response.body
  end

  def test_variant_any_with_none
    get :variant_any_with_none
    assert_equal "text/html", @response.content_type
    assert_equal "none or phone", @response.body

    @request.variant = :phone
    get :variant_any_with_none
    assert_equal "text/html", @response.content_type
    assert_equal "none or phone", @response.body
  end

  def test_format_any_variant_any
    @request.variant = :tablet
    get :format_any_variant_any, format: :js
    assert_equal "text/javascript", @response.content_type
    assert_equal "tablet", @response.body
  end

  def test_variant_negotiation_inline_syntax
    @request.variant = [:tablet, :phone]
    get :variant_inline_syntax_without_block
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body
  end

  def test_variant_negotiation_block_syntax
    @request.variant = [:tablet, :phone]
    get :variant_plus_none_for_format
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body
  end

  def test_variant_negotiation_without_block
    @request.variant = [:tablet, :phone]
    get :variant_inline_syntax_without_block
    assert_equal "text/html", @response.content_type
    assert_equal "phone", @response.body
  end
end
