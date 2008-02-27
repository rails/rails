require 'abstract_unit'

class WebServiceTest < Test::Unit::TestCase
  class MockCGI < CGI #:nodoc:
    attr_accessor :stdoutput, :env_table

    def initialize(env, data = '')
      self.env_table = env
      self.stdoutput = StringIO.new
      super(nil, StringIO.new(data))
    end
  end

  class TestController < ActionController::Base
    session :off

    def assign_parameters
      if params[:full]
        render :text => dump_params_keys
      else
        render :text => (params.keys - ['controller', 'action']).sort.join(", ")
      end
    end

    def dump_params_keys(hash=params)
      hash.keys.sort.inject("") do |s, k|
        value = hash[k]
        value = Hash === value ? "(#{dump_params_keys(value)})" : ""
        s << ", " unless s.empty?
        s << "#{k}#{value}"
      end
    end

    def rescue_action(e) raise end
  end
  
  def setup
    @controller = TestController.new
    @default_param_parsers = ActionController::Base.param_parsers.dup
  end

  def teardown
    ActionController::Base.param_parsers = @default_param_parsers
  end

  def test_check_parameters
    process('GET')
    assert_equal '', @controller.response.body
  end

  def test_post_xml
    process('POST', 'application/xml', '<entry attributed="true"><summary>content...</summary></entry>')
    
    assert_equal 'entry', @controller.response.body
    assert @controller.params.has_key?(:entry)
    assert_equal 'content...', @controller.params["entry"]['summary']
    assert_equal 'true', @controller.params["entry"]['attributed']
  end

  def test_put_xml
    process('PUT', 'application/xml', '<entry attributed="true"><summary>content...</summary></entry>')

    assert_equal 'entry', @controller.response.body
    assert @controller.params.has_key?(:entry)
    assert_equal 'content...', @controller.params["entry"]['summary']
    assert_equal 'true', @controller.params["entry"]['attributed']
  end

  def test_put_xml_using_a_type_node
    process('PUT', 'application/xml', '<type attributed="true"><summary>content...</summary></type>')

    assert_equal 'type', @controller.response.body
    assert @controller.params.has_key?(:type)
    assert_equal 'content...', @controller.params["type"]['summary']
    assert_equal 'true', @controller.params["type"]['attributed']
  end

  def test_put_xml_using_a_type_node_and_attribute
    process('PUT', 'application/xml', '<type attributed="true"><summary type="boolean">false</summary></type>')

    assert_equal 'type', @controller.response.body
    assert @controller.params.has_key?(:type)
    assert_equal false, @controller.params["type"]['summary']
    assert_equal 'true', @controller.params["type"]['attributed']
  end

  def test_post_xml_using_a_type_node
    process('POST', 'application/xml', '<font attributed="true"><type>arial</type></font>')

    assert_equal 'font', @controller.response.body
    assert @controller.params.has_key?(:font)
    assert_equal 'arial', @controller.params['font']['type']
    assert_equal 'true', @controller.params["font"]['attributed']
  end

  def test_post_xml_using_a_root_node_named_type
    process('POST', 'application/xml', '<type type="integer">33</type>')

    assert @controller.params.has_key?(:type)
    assert_equal 33, @controller.params['type']
  end

  def test_post_xml_using_an_attributted_node_named_type
    ActionController::Base.param_parsers[Mime::XML] = Proc.new { |data| XmlSimple.xml_in(data, 'ForceArray' => false) }
    process('POST', 'application/xml', '<request><type type="string">Arial,12</type><z>3</z></request>')

    assert_equal 'type, z', @controller.response.body
    assert @controller.params.has_key?(:type)
    assert_equal 'string', @controller.params['type']['type']
    assert_equal 'Arial,12', @controller.params['type']['content']
    assert_equal '3', @controller.params['z']
  end

  def test_register_and_use_yaml
    ActionController::Base.param_parsers[Mime::YAML] = Proc.new { |d| YAML.load(d) }
    process('POST', 'application/x-yaml', {"entry" => "loaded from yaml"}.to_yaml)
    assert_equal 'entry', @controller.response.body
    assert @controller.params.has_key?(:entry)
    assert_equal 'loaded from yaml', @controller.params["entry"]
  end
  
  def test_register_and_use_yaml_as_symbol
    ActionController::Base.param_parsers[Mime::YAML] = :yaml
    process('POST', 'application/x-yaml', {"entry" => "loaded from yaml"}.to_yaml)
    assert_equal 'entry', @controller.response.body
    assert @controller.params.has_key?(:entry)
    assert_equal 'loaded from yaml', @controller.params["entry"]
  end

  def test_register_and_use_xml_simple
    ActionController::Base.param_parsers[Mime::XML] = Proc.new { |data| XmlSimple.xml_in(data, 'ForceArray' => false) }
    process('POST', 'application/xml', '<request><summary>content...</summary><title>SimpleXml</title></request>' )
    assert_equal 'summary, title', @controller.response.body
    assert @controller.params.has_key?(:summary)
    assert @controller.params.has_key?(:title)
    assert_equal 'content...', @controller.params["summary"]
    assert_equal 'SimpleXml', @controller.params["title"]
  end

  def test_use_xml_ximple_with_empty_request
    ActionController::Base.param_parsers[Mime::XML] = :xml_simple
    assert_nothing_raised { process('POST', 'application/xml', "") }
    assert_equal "", @controller.response.body
  end

  def test_dasherized_keys_as_xml
    ActionController::Base.param_parsers[Mime::XML] = :xml_simple
    process('POST', 'application/xml', "<first-key>\n<sub-key>...</sub-key>\n</first-key>", true)
    assert_equal 'action, controller, first_key(sub_key), full', @controller.response.body
    assert_equal "...", @controller.params[:first_key][:sub_key]
  end

  def test_typecast_as_xml
    ActionController::Base.param_parsers[Mime::XML] = :xml_simple
    process('POST', 'application/xml', <<-XML)
      <data>
        <a type="integer">15</a>
        <b type="boolean">false</b>
        <c type="boolean">true</c>
        <d type="date">2005-03-17</d>
        <e type="datetime">2005-03-17T21:41:07Z</e>
        <f>unparsed</f>
        <g type="integer">1</g>
        <g>hello</g>
        <g type="date">1974-07-25</g>
      </data>
    XML
    params = @controller.params
    assert_equal 15, params[:data][:a]
    assert_equal false, params[:data][:b]
    assert_equal true, params[:data][:c]
    assert_equal Date.new(2005,3,17), params[:data][:d]
    assert_equal Time.utc(2005,3,17,21,41,7), params[:data][:e]
    assert_equal "unparsed", params[:data][:f]
    assert_equal [1, "hello", Date.new(1974,7,25)], params[:data][:g]
  end

  def test_entities_unescaped_as_xml_simple
    ActionController::Base.param_parsers[Mime::XML] = :xml_simple
    process('POST', 'application/xml', <<-XML)
      <data>&lt;foo &quot;bar&apos;s&quot; &amp; friends&gt;</data>
    XML
    assert_equal %(<foo "bar's" & friends>), @controller.params[:data]
  end

  def test_typecast_as_yaml
    ActionController::Base.param_parsers[Mime::YAML] = :yaml
    process('POST', 'application/x-yaml', <<-YAML)
      ---
      data:
        a: 15
        b: false
        c: true
        d: 2005-03-17
        e: 2005-03-17T21:41:07Z
        f: unparsed
        g:
          - 1
          - hello
          - 1974-07-25
    YAML
    params = @controller.params
    assert_equal 15, params[:data][:a]
    assert_equal false, params[:data][:b]
    assert_equal true, params[:data][:c]
    assert_equal Date.new(2005,3,17), params[:data][:d]
    assert_equal Time.utc(2005,3,17,21,41,7), params[:data][:e]
    assert_equal "unparsed", params[:data][:f]
    assert_equal [1, "hello", Date.new(1974,7,25)], params[:data][:g]
  end
  
  private  
  
  def process(verb, content_type = 'application/x-www-form-urlencoded', data = '', full=false)
    
    cgi = MockCGI.new({
      'REQUEST_METHOD' => verb,
      'CONTENT_TYPE'   => content_type,
      'QUERY_STRING'   => "action=assign_parameters&controller=webservicetest/test#{"&full=1" if full}",
      "REQUEST_URI"    => "/",
      "HTTP_HOST"      => 'testdomain.com',
      "CONTENT_LENGTH" => data.size,
      "SERVER_PORT"    => "80",
      "HTTPS"          => "off"}, data)
          
    @controller.send(:process, ActionController::CgiRequest.new(cgi, {}), ActionController::CgiResponse.new(cgi))
  end
    
end
