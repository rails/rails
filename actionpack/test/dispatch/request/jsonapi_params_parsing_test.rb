require 'abstract_unit'

class JsonapiParamsParsingTest < ActionDispatch::IntegrationTest
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

  test "parses jsonapi params for application/vnd.api+json" do
    payload = "{ \"data\": { \"type\": \"posts\", \"attributes\": { \"title\":"\
              "\"Hello\", \"date\": \"today\"} , \"relationships\": { "\
              "\"author\": { \"data\": { \"id\": \"2\", \"type\": \"users\" }"\
              " }, \"comments\": { \"data\": [ { \"type\": \"comments\","\
              "\"id\": \"3\" }, { \"type\": \"comments\", \"id\": \"4\" } ]"\
              " }, \"journal\": { \"data\": null } } } }"
    expected = { "_type" => "posts", "title" => "Hello", "date" => "today",
                 "author_id" => "2", "author_type" => "User",
                 "comment_ids" => ["3", "4"], "comment_types" => ["Comment", "Comment"],
                 "journal_id" => nil }
    assert_parses(expected, payload, { 'CONTENT_TYPE' => 'application/vnd.api+json' })
  end

  private
    def assert_parses(expected, actual, headers = {})
      with_test_routing do
        post "/parse", params: actual, headers: headers
        assert_response :ok
        assert_equal(expected, TestController.last_request_parameters)
      end
    end

    def with_test_routing
      with_routing do |set|
        set.draw do
          ActiveSupport::Deprecation.silence do
            post ':action', :to => ::JsonapiParamsParsingTest::TestController
          end
        end
        yield
      end
    end
end
