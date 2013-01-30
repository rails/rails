require 'abstract_unit'

class JsonParamsParsingTest < ActionController::IntegrationTest
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
      {"person" => []},
      "{\"person\":[]}", { 'CONTENT_TYPE' => 'application/json' }
    )
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
      begin
        $stderr = StringIO.new
        json = "[\"person]\": {\"name\": \"David\"}}"
        post "/parse", json, {'CONTENT_TYPE' => 'application/json', 'action_dispatch.show_exceptions' => true}
        assert_response :error
        $stderr.rewind && err = $stderr.read
        assert err =~ /Error occurred while parsing request parameters/
      ensure
        $stderr = STDERR
      end
    end
  end

  test "parses json with non-object JSON content" do
    assert_parses(
      {"_json" => "string content" },
      "\"string content\"", { 'CONTENT_TYPE' => 'application/json' }
    )
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
        set.draw do |map|
          match ':action', :to => ::JsonParamsParsingTest::TestController
        end
        yield
      end
    end
end
