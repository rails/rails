require File.dirname(__FILE__) + '/abstract_unit'

class JsonFoo
  def initialize(a, b)
    @a, @b = a, b
  end
end

class TestJSONEmitters < Test::Unit::TestCase
  TrueTests     = [[ true,  %(true)  ]]
  FalseTests    = [[ false, %(false) ]]
  NilTests      = [[ nil,   %(null)  ]]
  NumericTests  = [[ 1,     %(1)     ],
                   [ 2.5,   %(2.5)   ]]

  StringTests   = [[ 'this is the string',     %("this is the string")         ],
                   [ 'a "string" with quotes<script>', %("a \\"string\\" with quotes\\074script\\076") ]]

  ArrayTests    = [[ ['a', 'b', 'c'],          %([\"a\", \"b\", \"c\"])          ],
                   [ [1, 'a', :b, nil, false], %([1, \"a\", \"b\", null, false]) ]]

  SymbolTests   = [[ :a,     %("a")    ],
                   [ :this,  %("this") ],
                   [ :"a b", %("a b")  ]]

  ObjectTests   = [[ JsonFoo.new(1, 2), %({\"a\": 1, \"b\": 2}) ]]

  VariableTests = [[ ActiveSupport::JSON::Variable.new('foo'), 'foo'],
                   [ ActiveSupport::JSON::Variable.new('alert("foo")'), 'alert("foo")']]
  RegexpTests   = [[ /^a/, '/^a/' ], [/^\w{1,2}[a-z]+/ix, '/^\\w{1,2}[a-z]+/ix']]

  constants.grep(/Tests$/).each do |class_tests|
    define_method("test_#{class_tests[0..-6].downcase}") do
      self.class.const_get(class_tests).each do |pair|
        assert_equal pair.last, pair.first.to_json
      end
    end
  end

  def setup
    unquote(false)
  end
  
  def teardown
    unquote(true)
  end
  
  def test_hash_encoding
    assert_equal %({\"a\": \"b\"}), { :a => :b }.to_json
    assert_equal %({\"a\": 1}), { 'a' => 1  }.to_json
    assert_equal %({\"a\": [1, 2]}), { 'a' => [1,2] }.to_json
    
    sorted_json  = 
      '{' + {:a => :b, :c => :d}.to_json[1..-2].split(', ').sort.join(', ') + '}'
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
  
  def test_unquote_hash_key_identifiers
    values = {0 => 0, 1 => 1, :_ => :_, "$" => "$", "a" => "a", :A => :A, :A0 => :A0, "A0B" => "A0B"}    
    
    assert_equal %({"a": "a"}), {"a"=>"a"}.to_json
    assert_equal %({0: 0}),   { 0 => 0 }.to_json
    assert_equal %({"_": "_"}), {:_ =>:_ }.to_json
    assert_equal %({"$": "$"}), {"$"=>"$"}.to_json
    
    unquote(true) do
      assert_equal %({a: "a"}), {"a"=>"a"}.to_json
      assert_equal %({0: 0}),   { 0 => 0 }.to_json
      assert_equal %({_: "_"}), {:_ =>:_ }.to_json
      assert_equal %({$: "$"}), {"$"=>"$"}.to_json
    end
  end
  
  protected
    def unquote(value)
      previous_value = ActiveSupport::JSON.unquote_hash_key_identifiers
      ActiveSupport::JSON.unquote_hash_key_identifiers = value
      yield if block_given?
    ensure
      ActiveSupport::JSON.unquote_hash_key_identifiers = previous_value if block_given?
    end
    
end
