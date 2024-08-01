# frozen_string_literal: true

require "abstract_unit"

class UrlEncodedParamsParsingTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    class << self
      attr_accessor :last_request_parameters, :last_request_type
    end

    def parse
      self.class.last_request_parameters = request.request_parameters
      head :ok
    end
  end

  def teardown
    TestController.last_request_parameters = nil
  end

  test "parses unbalanced query string with array" do
    query    = "location[]=1&location[]=2&age_group[]=2"
    expected = { "location" => ["1", "2"], "age_group" => ["2"] }
    assert_parses expected, query
  end

  test "parses nested hash" do
    query = [
      "note[viewers][viewer][][type]=User",
      "note[viewers][viewer][][id]=1",
      "note[viewers][viewer][][type]=Group",
      "note[viewers][viewer][][id]=2"
    ].join("&")
    expected = {
      "note" => {
        "viewers" => {
          "viewer" => [
            { "id" => "1", "type" => "User" },
            { "type" => "Group", "id" => "2" }
          ]
        }
      }
    }
    assert_parses expected, query
  end

  test "parses more complex nesting" do
    query = [
      "customers[boston][first][name]=David",
      "customers[boston][first][url]=http://David",
      "customers[boston][second][name]=Allan",
      "customers[boston][second][url]=http://Allan",
      "something_else=blah",
      "something_nil=",
      "something_empty=",
      "products[first]=Apple Computer",
      "products[second]=Pc",
      "=Save"
    ].join("&")
    expected = {
      "customers" => {
        "boston" => {
          "first" => {
            "name" => "David",
            "url" => "http://David"
          },
          "second" => {
            "name" => "Allan",
            "url" => "http://Allan"
          }
        }
      },
      "something_else" => "blah",
      "something_empty" => "",
      "something_nil" => "",
      "products" => {
        "first" => "Apple Computer",
        "second" => "Pc"
      }
    }
    assert_parses expected, query
  end

  test "parses params with array" do
    query    = "selected[]=1&selected[]=2&selected[]=3"
    expected = { "selected" => ["1", "2", "3"] }
    assert_parses expected, query
  end

  test "parses params with nil key" do
    query    = "=&test2=value1"
    expected = { "test2" => "value1" }
    assert_parses expected, query
  end

  test "parses params with array prefix and hashes" do
    query    = "a[][b][c]=d"
    expected = { "a" => [{ "b" => { "c" => "d" } }] }
    assert_parses expected, query
  end

  test "parses params with complex nesting" do
    query    = "a[][b][c][][d][]=e"
    expected = { "a" => [{ "b" => { "c" => [{ "d" => ["e"] }] } }] }
    assert_parses expected, query
  end

  test "parses params with file path" do
    query = [
      "customers[boston][first][name]=David",
      "something_else=blah",
      "logo=#{__FILE__}"
    ].join("&")
    expected = {
      "customers" => {
        "boston" => {
          "first" => {
            "name" => "David"
          }
        }
      },
      "something_else" => "blah",
      "logo" => __FILE__,
    }
    assert_parses expected, query
  end

  test "parses params with Safari 2 trailing null character" do
    query    = "selected[]=1&selected[]=2&selected[]=3\0"
    expected = { "selected" => ["1", "2", "3"] }
    assert_parses expected, query
  end

  test "ambiguous params returns a bad request" do
    with_test_routing do
      post "/parse", params: "foo[]=bar&foo[4]=bar"
      assert_response :bad_request
    end
  end

  private
    def with_test_routing
      with_routing do |set|
        set.draw do
          ActionDispatch.deprecator.silence do
            post ":action", to: ::UrlEncodedParamsParsingTest::TestController
          end
        end
        yield
      end
    end

    def assert_parses(expected, actual)
      with_test_routing do
        post "/parse", params: actual
        assert_response :ok
        assert_equal expected, TestController.last_request_parameters
        assert_utf8 TestController.last_request_parameters
      end
    end

    def assert_utf8(object)
      correct_encoding = Encoding.default_internal

      unless object.is_a?(Hash)
        assert_equal correct_encoding, object.encoding, "#{object.inspect} should have been UTF-8"
        return
      end

      object.each_value do |v|
        case v
        when Hash
          assert_utf8 v
        when Array
          v.each { |el| assert_utf8 el }
        else
          assert_utf8 v
        end
      end
    end
end
