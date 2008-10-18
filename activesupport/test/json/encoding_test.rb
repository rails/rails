# encoding: utf-8
require 'abstract_unit'

class TestJSONEncoding < Test::Unit::TestCase
  class Foo
    def initialize(a, b)
      @a, @b = a, b
    end
  end

  TrueTests     = [[ true,  %(true)  ]]
  FalseTests    = [[ false, %(false) ]]
  NilTests      = [[ nil,   %(null)  ]]
  NumericTests  = [[ 1,     %(1)     ],
                   [ 2.5,   %(2.5)   ]]

  StringTests   = [[ 'this is the <string>',     %("this is the \\u003Cstring\\u003E")],
                   [ 'a "string" with quotes & an ampersand', %("a \\"string\\" with quotes \\u0026 an ampersand") ],
                   [ 'http://test.host/posts/1', %("http://test.host/posts/1")]]

  ArrayTests    = [[ ['a', 'b', 'c'],          %([\"a\", \"b\", \"c\"])          ],
                   [ [1, 'a', :b, nil, false], %([1, \"a\", \"b\", null, false]) ]]

  SymbolTests   = [[ :a,     %("a")    ],
                   [ :this,  %("this") ],
                   [ :"a b", %("a b")  ]]

  ObjectTests   = [[ Foo.new(1, 2), %({\"a\": 1, \"b\": 2}) ]]

  VariableTests = [[ ActiveSupport::JSON::Variable.new('foo'), 'foo'],
                   [ ActiveSupport::JSON::Variable.new('alert("foo")'), 'alert("foo")']]
  RegexpTests   = [[ /^a/, '/^a/' ], [/^\w{1,2}[a-z]+/ix, '/^\\w{1,2}[a-z]+/ix']]

  DateTests     = [[ Date.new(2005,2,1), %("2005/02/01") ]]
  TimeTests     = [[ Time.utc(2005,2,1,15,15,10), %("2005/02/01 15:15:10 +0000") ]]
  DateTimeTests = [[ DateTime.civil(2005,2,1,15,15,10), %("2005/02/01 15:15:10 +0000") ]]

  StandardDateTests     = [[ Date.new(2005,2,1), %("2005-02-01") ]]
  StandardTimeTests     = [[ Time.utc(2005,2,1,15,15,10), %("2005-02-01T15:15:10Z") ]]
  StandardDateTimeTests = [[ DateTime.civil(2005,2,1,15,15,10), %("2005-02-01T15:15:10+00:00") ]]
  StandardStringTests   = [[ 'this is the <string>', %("this is the <string>")]]

  constants.grep(/Tests$/).each do |class_tests|
    define_method("test_#{class_tests[0..-6].underscore}") do
      begin
        ActiveSupport.escape_html_entities_in_json  = class_tests !~ /^Standard/
        ActiveSupport.use_standard_json_time_format = class_tests =~ /^Standard/
        self.class.const_get(class_tests).each do |pair|
          assert_equal pair.last, pair.first.to_json
        end
      ensure
        ActiveSupport.escape_html_entities_in_json  = false
        ActiveSupport.use_standard_json_time_format = false
      end
    end
  end

  def test_hash_encoding
    assert_equal %({\"a\": \"b\"}), { :a => :b }.to_json
    assert_equal %({\"a\": 1}), { 'a' => 1  }.to_json
    assert_equal %({\"a\": [1, 2]}), { 'a' => [1,2] }.to_json
    assert_equal %({1: 2}), { 1 => 2 }.to_json

    sorted_json = '{' + {:a => :b, :c => :d}.to_json[1..-2].split(', ').sort.join(', ') + '}'
    assert_equal %({\"a\": \"b\", \"c\": \"d\"}), sorted_json
  end

  def test_utf8_string_encoded_properly_when_kcode_is_utf8
    with_kcode 'UTF8' do
      assert_equal '"\\u20ac2.99"', '€2.99'.to_json
      assert_equal '"\\u270e\\u263a"', '✎☺'.to_json
    end
  end

  def test_exception_raised_when_encoding_circular_reference
    a = [1]
    a << a
    assert_raises(ActiveSupport::JSON::CircularReferenceError) { a.to_json }
  end

  def test_hash_key_identifiers_are_always_quoted
    values = {0 => 0, 1 => 1, :_ => :_, "$" => "$", "a" => "a", :A => :A, :A0 => :A0, "A0B" => "A0B"}
    assert_equal %w( "$" "A" "A0" "A0B" "_" "a" 0 1 ), object_keys(values.to_json)
  end

  def test_hash_should_allow_key_filtering_with_only
    assert_equal %({"a": 1}), { 'a' => 1, :b => 2, :c => 3 }.to_json(:only => 'a')
  end

  def test_hash_should_allow_key_filtering_with_except
    assert_equal %({"b": 2}), { 'foo' => 'bar', :b => 2, :c => 3 }.to_json(:except => ['foo', :c])
  end
  
  def test_time_to_json_includes_local_offset
    ActiveSupport.use_standard_json_time_format = true
    with_env_tz 'US/Eastern' do
      assert_equal %("2005-02-01T15:15:10-05:00"), Time.local(2005,2,1,15,15,10).to_json
    end
  ensure
    ActiveSupport.use_standard_json_time_format = false
  end

  def test_nested_hash_with_float
    assert_nothing_raised do
      hash = {
        "CHI" => {
          :dislay_name => "chicago",
          :latitude => 123.234
        }
      }
      result = hash.to_json
    end
  end

  protected

    def object_keys(json_object)
      json_object[1..-2].scan(/([^{}:,\s]+):/).flatten.sort
    end
    
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end

uses_mocha 'JsonOptionsTests' do
  class JsonOptionsTests < Test::Unit::TestCase
    def test_enumerable_should_passthrough_options_to_elements
      json_options = { :include => :posts }
      ActiveSupport::JSON.expects(:encode).with(1, json_options)
      ActiveSupport::JSON.expects(:encode).with(2, json_options)
      ActiveSupport::JSON.expects(:encode).with('foo', json_options)

      [1, 2, 'foo'].to_json(json_options)
    end
  end
end
