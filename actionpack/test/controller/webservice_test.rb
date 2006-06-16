require File.dirname(__FILE__) + '/../abstract_unit'
require 'stringio'

class WebServiceTest < Test::Unit::TestCase

  class MockCGI < CGI #:nodoc:
    attr_accessor :stdinput, :stdoutput, :env_table

    def initialize(env, data = '')      
      self.env_table = env
      self.stdinput = StringIO.new(data)
      self.stdoutput = StringIO.new
      super()
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
    ActionController::Base.param_parsers.clear
    ActionController::Base.param_parsers[Mime::XML] = :xml_node
  end
  
  def test_check_parameters
    process('GET')
    assert_equal '', @controller.response.body
  end

  def test_post_xml
    process('POST', 'application/xml', '<entry attributed="true"><summary>content...</summary></entry>')
    
    assert_equal 'entry', @controller.response.body
    assert @controller.params.has_key?(:entry)
    assert_equal 'content...', @controller.params["entry"].summary.node_value
    assert_equal 'true', @controller.params["entry"]['attributed']
  end
  
  def test_put_xml
    process('PUT', 'application/xml', '<entry attributed="true"><summary>content...</summary></entry>')
    
    assert_equal 'entry', @controller.response.body
    assert @controller.params.has_key?(:entry)
    assert_equal 'content...', @controller.params["entry"].summary.node_value
    assert_equal 'true', @controller.params["entry"]['attributed']
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
  
  def test_deprecated_request_methods
    process('POST', 'application/x-yaml')
    assert_equal Mime::YAML, @controller.request.content_type
    assert_equal true, @controller.request.post?
    assert_equal :yaml, @controller.request.post_format
    assert_equal true, @controller.request.yaml_post?
    assert_equal false, @controller.request.xml_post?    
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


class XmlNodeTest < Test::Unit::TestCase
  def test_all
    xn = XmlNode.from_xml(%{<?xml version="1.0" encoding="UTF-8"?>
      <response success='true'>
      <page title='Ajax Summit' id='1133' email_address='ry87ib@backpackit.com'>
        <description>With O'Reilly and Adaptive Path</description>
        <notes>
          <note title='Hotel' id='1020' created_at='2005-05-14 16:41:11'>
            Staying at the Savoy
          </note>
        </notes>
        <tags>
          <tag name='Technology' id='4' />
          <tag name='Travel' id='5' />
        </tags>
      </page>
      </response>
     }
    )     
    assert_equal 'UTF-8', xn.node.document.encoding
    assert_equal '1.0', xn.node.document.version
    assert_equal 'true', xn['success']
    assert_equal 'response', xn.node_name
    assert_equal 'Ajax Summit', xn.page['title']
    assert_equal '1133', xn.page['id']
    assert_equal "With O'Reilly and Adaptive Path", xn.page.description.node_value
    assert_equal nil, xn.nonexistent
    assert_equal "Staying at the Savoy", xn.page.notes.note.node_value.strip
    assert_equal 'Technology', xn.page.tags.tag[0]['name']
    assert_equal 'Travel', xn.page.tags.tag[1][:name]
    matches = xn.xpath('//@id').map{ |id| id.to_i }
    assert_equal [4, 5, 1020, 1133], matches.sort
    matches = xn.xpath('//tag').map{ |tag| tag['name'] }
    assert_equal ['Technology', 'Travel'], matches.sort
    assert_equal "Ajax Summit", xn.page['title']
    xn.page['title'] = 'Ajax Summit V2'
    assert_equal "Ajax Summit V2", xn.page['title']
    assert_equal "Staying at the Savoy", xn.page.notes.note.node_value.strip
    xn.page.notes.note.node_value = "Staying at the Ritz"
    assert_equal "Staying at the Ritz", xn.page.notes.note.node_value.strip
    assert_equal '5', xn.page.tags.tag[1][:id]
    xn.page.tags.tag[1]['id'] = '7'
    assert_equal '7', xn.page.tags.tag[1]['id']
  end
  

  def test_small_entry
    node = XmlNode.from_xml('<entry>hi</entry>')
    assert_equal 'hi', node.node_value
  end

end
