# encoding: UTF-8
require 'abstract_unit'
require 'active_support/json'
require 'active_support/time'
require 'active_support/core_ext/kernel/reporting'

class TestJSONDecoding < ActiveSupport::TestCase
  TESTS = {
    %q({"returnTo":{"\/categories":"\/"}})        => {"returnTo" => {"/categories" => "/"}},
    %q({"return\\"To\\":":{"\/categories":"\/"}}) => {"return\"To\":" => {"/categories" => "/"}},
    %q({"returnTo":{"\/categories":1}})          => {"returnTo" => {"/categories" => 1}},
    %({"returnTo":[1,"a"]})                    => {"returnTo" => [1, "a"]},
    %({"returnTo":[1,"\\"a\\",", "b"]})        => {"returnTo" => [1, "\"a\",", "b"]},
    %({"a": "'", "b": "5,000"})                  => {"a" => "'", "b" => "5,000"},
    %({"a": "a's, b's and c's", "b": "5,000"})   => {"a" => "a's, b's and c's", "b" => "5,000"},
    # multibyte
    %({"matzue": "松江", "asakusa": "浅草"}) => {"matzue" => "松江", "asakusa" => "浅草"},
    %({"a": "2007-01-01"})                       => {'a' => Date.new(2007, 1, 1)},
    %({"a": "2007-01-01 01:12:34 Z"})            => {'a' => Time.utc(2007, 1, 1, 1, 12, 34)},
    # no time zone
    %({"a": "2007-01-01 01:12:34"})              => {'a' => "2007-01-01 01:12:34"},
    # invalid date
    %({"a": "1089-10-40"})                       => {'a' => "1089-10-40"},
    # xmlschema date notation
    %({"a": "2009-08-10T19:01:02Z"})             => {'a' => Time.utc(2009, 8, 10, 19, 1, 2)},
    %({"a": "2009-08-10T19:01:02+02:00"})        => {'a' => Time.utc(2009, 8, 10, 17, 1, 2)},
    %({"a": "2009-08-10T19:01:02-05:00"})        => {'a' => Time.utc(2009, 8, 11, 00, 1, 2)},
    # needs to be *exact*
    %({"a": " 2007-01-01 01:12:34 Z "})          => {'a' => " 2007-01-01 01:12:34 Z "},
    %({"a": "2007-01-01 : it's your birthday"})  => {'a' => "2007-01-01 : it's your birthday"},
    %([])    => [],
    %({})    => {},
    %({"a":1})     => {"a" => 1},
    %({"a": ""})    => {"a" => ""},
    %({"a":"\\""}) => {"a" => "\""},
    %({"a": null})  => {"a" => nil},
    %({"a": true})  => {"a" => true},
    %({"a": false}) => {"a" => false},
    %q({"bad":"\\\\","trailing":""}) => {"bad" => "\\", "trailing" => ""},
    %q({"a": "http:\/\/test.host\/posts\/1"}) => {"a" => "http://test.host/posts/1"},
    %q({"a": "\u003cunicode\u0020escape\u003e"}) => {"a" => "<unicode escape>"},
    %q({"a": "\\\\u0020skip double backslashes"}) => {"a" => "\\u0020skip double backslashes"},
    %q({"a": "\u003cbr /\u003e"}) => {'a' => "<br />"},
    %q({"b":["\u003ci\u003e","\u003cb\u003e","\u003cu\u003e"]}) => {'b' => ["<i>","<b>","<u>"]},
    # test combination of dates and escaped or unicode encoded data in arrays
    %q([{"d":"1970-01-01", "s":"\u0020escape"},{"d":"1970-01-01", "s":"\u0020escape"}]) =>
      [{'d' => Date.new(1970, 1, 1), 's' => ' escape'},{'d' => Date.new(1970, 1, 1), 's' => ' escape'}],
    %q([{"d":"1970-01-01","s":"http:\/\/example.com"},{"d":"1970-01-01","s":"http:\/\/example.com"}]) =>
      [{'d' => Date.new(1970, 1, 1), 's' => 'http://example.com'},
       {'d' => Date.new(1970, 1, 1), 's' => 'http://example.com'}],
    # tests escaping of "\n" char with Yaml backend
    %q({"a":"\n"})  => {"a"=>"\n"},
    %q({"a":"\u000a"}) => {"a"=>"\n"},
    %q({"a":"Line1\u000aLine2"}) => {"a"=>"Line1\nLine2"}
  }

  # load the default JSON backend
  ActiveSupport::JSON.backend = 'OkJson'

  backends = %w(OkJson)
  backends << "JSONGem" if defined?(::JSON)
  backends << "Yajl" if defined?(::Yajl)

  backends.each do |backend|
    TESTS.each do |json, expected|
      test "json decodes #{json} with the #{backend} backend" do
        ActiveSupport.parse_json_times = true
        silence_warnings do
          ActiveSupport::JSON.with_backend backend do
            assert_equal expected, ActiveSupport::JSON.decode(json)
          end
        end
      end
    end
  end

  if backends.include?("JSONGem")
    test "json decodes time json with time parsing disabled" do
      ActiveSupport.parse_json_times = false
      expected = {"a" => "2007-01-01 01:12:34 Z"}
      ActiveSupport::JSON.with_backend "JSONGem" do
        assert_equal expected, ActiveSupport::JSON.decode(%({"a": "2007-01-01 01:12:34 Z"}))
      end
    end
  end

  def test_failed_json_decoding
    assert_raise(ActiveSupport::JSON.parse_error) { ActiveSupport::JSON.decode(%({: 1})) }
  end
end

