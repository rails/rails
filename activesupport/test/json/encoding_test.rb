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

  StringTests   = [[ 'this is the <string>',     %("this is the \\074string\\076")],
                   [ 'a "string" with quotes', %("a \\"string\\" with quotes") ]]

  ArrayTests    = [[ ['a', 'b', 'c'],          %([\"a\", \"b\", \"c\"])          ],
                   [ [1, 'a', :b, nil, false], %([1, \"a\", \"b\", null, false]) ]]

  SymbolTests   = [[ :a,     %("a")    ],
                   [ :this,  %("this") ],
                   [ :"a b", %("a b")  ]]

  ObjectTests   = [[ Foo.new(1, 2), %({\"a\": 1, \"b\": 2}) ]]

  VariableTests = [[ ActiveSupport::JSON::Variable.new('foo'), 'foo'],
                   [ ActiveSupport::JSON::Variable.new('alert("foo")'), 'alert("foo")']]
  RegexpTests   = [[ /^a/, '/^a/' ], [/^\w{1,2}[a-z]+/ix, '/^\\w{1,2}[a-z]+/ix']]

  DateTests     = [[ Date.new(2005,1,1), %("01/01/2005") ]]
  TimeTests     = [[ Time.at(0), %("#{Time.at(0).strftime('%m/%d/%Y %H:%M:%S %Z')}") ]]
  DateTimeTests = [[ DateTime.new(0), %("#{DateTime.new(0).strftime('%m/%d/%Y %H:%M:%S %Z')}") ]]

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

    sorted_json = '{' + {:a => :b, :c => :d}.to_json[1..-2].split(', ').sort.join(', ') + '}'
    assert_equal %({\"a\": \"b\", \"c\": \"d\"}), sorted_json
  end

  def test_utf8_string_encoded_properly_when_kcode_is_utf8
    old_kcode, $KCODE = $KCODE, 'UTF8'
    assert_equal '"\\u20ac2.99"', '€2.99'.to_json
    assert_equal '"\\u270e\\u263a"', '✎☺'.to_json
  ensure
    $KCODE = old_kcode
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

  protected
    def object_keys(json_object)
      json_object[1..-2].scan(/([^{}:,\s]+):/).flatten.sort
    end
end
