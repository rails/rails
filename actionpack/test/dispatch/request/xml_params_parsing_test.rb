require 'abstract_unit'

class XmlParamsParsingTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    class << self
      attr_accessor :last_request_parameters
    end

    def parse
      self.class.last_request_parameters = request.request_parameters
      head :ok
    end
  end

  def teardown
    TestController.last_request_parameters = nil
  end

  test "parses a strict rack.input" do
    class Linted
      undef call if method_defined?(:call)
      def call(env)
        bar = env['action_dispatch.request.request_parameters']['foo']
        result = "<ok>#{bar}</ok>"
        [200, {"Content-Type" => "application/xml", "Content-Length" => result.length.to_s}, [result]]
      end
    end
    req = Rack::MockRequest.new(ActionDispatch::ParamsParser.new(Linted.new))
    resp = req.post('/', "CONTENT_TYPE" => "application/xml", :input => "<foo>bar</foo>", :lint => true)
    assert_equal "<ok>bar</ok>", resp.body
  end

  def assert_parses(expected, xml)
    with_test_routing do
      post "/parse", xml, default_headers
      assert_response :ok
      assert_equal(expected, TestController.last_request_parameters)
    end
  end

  test "nils are stripped from collections" do
    assert_parses(
      {"hash" => { "person" => nil} },
      "<hash><person type=\"array\"><person nil=\"true\"/></person></hash>")
    assert_parses(
      {"hash" => { "person" => ['foo']} },
      "<hash><person type=\"array\"><person>foo</person><person nil=\"true\"/></person>\n</hash>")
  end

  test "parses hash params" do
    with_test_routing do
      xml = "<person><name>David</name></person>"
      post "/parse", xml, default_headers
      assert_response :ok
      assert_equal({"person" => {"name" => "David"}}, TestController.last_request_parameters)
    end
  end

  test "parses single file" do
    with_test_routing do
      xml = "<person><name>David</name><avatar type='file' name='me.jpg' content_type='image/jpg'>#{::Base64.encode64('ABC')}</avatar></person>"
      post "/parse", xml, default_headers
      assert_response :ok

      person = TestController.last_request_parameters
      assert_equal "image/jpg", person['person']['avatar'].content_type
      assert_equal "me.jpg", person['person']['avatar'].original_filename
      assert_equal "ABC", person['person']['avatar'].read
    end
  end

  test "logs error if parsing unsuccessful" do
    with_test_routing do
      output = StringIO.new
      xml = "<person><name>David</name><avatar type='file' name='me.jpg' content_type='image/jpg'>#{::Base64.encode64('ABC')}</avatar></pineapple>"
      post "/parse", xml, default_headers.merge('action_dispatch.show_exceptions' => true, 'action_dispatch.logger' => ActiveSupport::Logger.new(output))
      assert_response :error
      output.rewind && err = output.read
      assert err =~ /Error occurred while parsing request parameters/
    end
  end

  test "occurring a parse error if parsing unsuccessful" do
    with_test_routing do
      begin
        $stderr = StringIO.new # suppress the log
        xml = "<person><name>David</name></pineapple>"
        exception = assert_raise(ActionDispatch::ParamsParser::ParseError) { post "/parse", xml, default_headers.merge('action_dispatch.show_exceptions' => false) }
        assert_equal REXML::ParseException, exception.original_exception.class
        assert_equal exception.original_exception.message, exception.message
      ensure
        $stderr = STDERR
      end
    end
  end

  test "parses multiple files" do
    xml = <<-end_body
      <person>
        <name>David</name>
        <avatars>
          <avatar type='file' name='me.jpg' content_type='image/jpg'>#{::Base64.encode64('ABC')}</avatar>
          <avatar type='file' name='you.gif' content_type='image/gif'>#{::Base64.encode64('DEF')}</avatar>
        </avatars>
      </person>
    end_body

    with_test_routing do
      post "/parse", xml, default_headers
      assert_response :ok
    end

    person = TestController.last_request_parameters

    assert_equal "image/jpg", person['person']['avatars']['avatar'].first.content_type
    assert_equal "me.jpg", person['person']['avatars']['avatar'].first.original_filename
    assert_equal "ABC", person['person']['avatars']['avatar'].first.read

    assert_equal "image/gif", person['person']['avatars']['avatar'].last.content_type
    assert_equal "you.gif", person['person']['avatars']['avatar'].last.original_filename
    assert_equal "DEF", person['person']['avatars']['avatar'].last.read
  end

  private
    def with_test_routing
      with_routing do |set|
        set.draw do
          post ':action', :to => ::XmlParamsParsingTest::TestController
        end
        yield
      end
    end

    def default_headers
      {'CONTENT_TYPE' => 'application/xml'}
    end
end

class LegacyXmlParamsParsingTest < XmlParamsParsingTest
  private
    def default_headers
      {'HTTP_X_POST_DATA_FORMAT' => 'xml'}
    end
end

class RootLessXmlParamsParsingTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    wrap_parameters :person, :format => :xml

    class << self
      attr_accessor :last_request_parameters
    end

    def parse
      self.class.last_request_parameters = request.request_parameters
      head :ok
    end
  end

  def teardown
    TestController.last_request_parameters = nil
  end

  test "parses hash params" do
    with_test_routing do
      xml = "<name>David</name>"
      post "/parse", xml, {'CONTENT_TYPE' => 'application/xml'}
      assert_response :ok
      assert_equal({"name" => "David", "person" => {"name" => "David"}}, TestController.last_request_parameters)
    end
  end

  private
    def with_test_routing
      with_routing do |set|
        set.draw do
          post ':action', :to => ::RootLessXmlParamsParsingTest::TestController
        end
        yield
      end
    end
end
