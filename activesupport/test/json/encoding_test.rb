require File.dirname(__FILE__) + '/../abstract_unit'

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

  constants.grep(/Tests$/).each do |class_tests|
    define_method("test_#{class_tests[0..-6].downcase}") do
      self.class.const_get(class_tests).each do |pair|
        assert_equal pair.last, pair.first.to_json
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

  protected
    def with_kcode(code)
      if RUBY_VERSION < '1.9'
        begin
          old_kcode, $KCODE = $KCODE, 'UTF8'
          yield
        ensure
          $KCODE = old_kcode
        end
      else
        yield
      end
    end

    def object_keys(json_object)
      json_object[1..-2].scan(/([^{}:,\s]+):/).flatten.sort
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
