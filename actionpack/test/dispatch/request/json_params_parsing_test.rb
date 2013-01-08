require 'abstract_unit'

class JsonParamsParsingTest < ActionDispatch::IntegrationTest
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

  test "parses json params for application json" do
    assert_parses(
      {"person" => {"name" => "David"}},
      "{\"person\": {\"name\": \"David\"}}", { 'CONTENT_TYPE' => 'application/json' }
    )
  end

  test "parses json params for application jsonrequest" do
    assert_parses(
      {"person" => {"name" => "David"}},
      "{\"person\": {\"name\": \"David\"}}", { 'CONTENT_TYPE' => 'application/jsonrequest' }
    )
  end

  test "nils are stripped from collections" do
    assert_parses(
      {"person" => nil},
      "{\"person\":[null]}", { 'CONTENT_TYPE' => 'application/json' }
    )
    assert_parses(
      {"person" => ['foo']},
      "{\"person\":[\"foo\",null]}", { 'CONTENT_TYPE' => 'application/json' }
    )
    assert_parses(
      {"person" => nil},
      "{\"person\":[null, null]}", { 'CONTENT_TYPE' => 'application/json' }
    )
  end

  test "logs error if parsing unsuccessful" do
    with_test_routing do
      output = StringIO.new
      json = "[\"person]\": {\"name\": \"David\"}}"
      post "/parse", json, {'CONTENT_TYPE' => 'application/json', 'action_dispatch.show_exceptions' => true, 'action_dispatch.logger' => Logger.new(output)}
      assert_response :error
      output.rewind && err = output.read
      assert err =~ /Error occurred while parsing request parameters/
    end
  end

  test "occurring a parse error if parsing unsuccessful" do
    with_test_routing do
      begin
        $stderr = StringIO.new # suppress the log
        json = "[\"person]\": {\"name\": \"David\"}}"
        assert_raise(MultiJson::DecodeError) { post "/parse", json, {'CONTENT_TYPE' => 'application/json', 'action_dispatch.show_exceptions' => false} }
      ensure
        $stderr = STDERR
      end
    end
  end

  private
    def assert_parses(expected, actual, headers = {})
      with_test_routing do
        post "/parse", actual, headers
        assert_response :ok
        assert_equal(expected, TestController.last_request_parameters)
      end
    end

    def with_test_routing
      with_routing do |set|
        set.draw do
          match ':action', :to => ::JsonParamsParsingTest::TestController
        end
        yield
      end
    end
end

class RootLessJSONParamsParsingTest < ActionDispatch::IntegrationTest
  class UsersController < ActionController::Base
    wrap_parameters :format => :json

    class << self
      attr_accessor :last_request_parameters, :last_parameters
    end

    def parse
      self.class.last_request_parameters = request.request_parameters
      self.class.last_parameters = params
      head :ok
    end
  end

  def teardown
    UsersController.last_request_parameters = nil
  end

  test "parses json params for application json" do
    assert_parses(
      {"user" => {"username" => "sikachu"}, "username" => "sikachu"},
      "{\"username\": \"sikachu\"}", { 'CONTENT_TYPE' => 'application/json' }
    )
  end

  test "parses json params for application jsonrequest" do
    assert_parses(
      {"user" => {"username" => "sikachu"}, "username" => "sikachu"},
      "{\"username\": \"sikachu\"}", { 'CONTENT_TYPE' => 'application/jsonrequest' }
    )
  end

  private
    def assert_parses(expected, actual, headers = {})
      with_test_routing(UsersController) do
        post "/parse", actual, headers
        assert_response :ok
        assert_equal(expected, UsersController.last_request_parameters)
        assert_equal(expected.merge({"action" => "parse"}), UsersController.last_parameters)
      end
    end

    def with_test_routing(controller)
      with_routing do |set|
        set.draw do
          match ':action', :to => controller
        end
        yield
      end
    end
end
