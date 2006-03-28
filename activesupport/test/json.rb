$:.unshift File.dirname(__FILE__) + '/../lib'
require 'active_support'
require 'test/unit'

class Foo
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
                   [ 'a "string" with quotes', %("a \\"string\\" with quotes") ]]
                 
  ArrayTests    = [[ ['a', 'b', 'c'],          %([\"a\", \"b\", \"c\"])          ],
                   [ [1, 'a', :b, nil, false], %([1, \"a\", \"b\", null, false]) ]]
  
  HashTests     = [[ {:a => :b, :c => :d}, %({\"c\": \"d\", \"a\": \"b\"}) ]]
                  
  SymbolTests   = [[ :a,     %("a")    ],
                   [ :this,  %("this") ],
                   [ :"a b", %("a b")  ]]

  ObjectTests   = [[ Foo.new(1, 2), %({\"a\": 1, \"b\": 2}) ]]

  VariableTests = [[ ActiveSupport::JSON::Variable.new('foo'), 'foo'],
                   [ ActiveSupport::JSON::Variable.new('alert("foo")'), 'alert("foo")']]
  RegexpTests   = [[ /^a/, '/^a/' ], /^\w{1,2}[a-z]+/ix, '/^\\w{1,2}[a-z]+/ix']

  constants.grep(/Tests$/).each do |class_tests|
    define_method("test_#{class_tests[0..-6].downcase}") do
      self.class.const_get(class_tests).each do |pair|
        assert_equal pair.last, pair.first.to_json
      end
    end
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
end
