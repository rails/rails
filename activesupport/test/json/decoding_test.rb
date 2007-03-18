require File.dirname(__FILE__) + '/../abstract_unit'

class TestJSONDecoding < Test::Unit::TestCase
  TESTS = {
    %({"returnTo":{"/categories":"/"}})        => {"returnTo" => {"/categories" => "/"}},
    %({returnTo:{"/categories":"/"}})          => {"returnTo" => {"/categories" => "/"}},
    %({"return\\"To\\":":{"/categories":"/"}}) => {"return\"To\":" => {"/categories" => "/"}},
    %({"returnTo":{"/categories":1}})          => {"returnTo" => {"/categories" => 1}},
    %({"returnTo":[1,"a"]})                    => {"returnTo" => [1, "a"]},
    %({"returnTo":[1,"\\"a\\",", "b"]})        => {"returnTo" => [1, "\"a\",", "b"]},
    %([])    => [],
    %({})    => {},
    %(1)     => 1,
    %("")    => "",
    %("\\"") => "\"",
    %(null)  => nil,
    %(true)  => true,
    %(false) => false
  }
  
  def test_json_decoding
    TESTS.each do |json, expected|
      assert_nothing_raised do
        assert_equal expected, ActiveSupport::JSON.decode(json)
      end
    end
  end
end
