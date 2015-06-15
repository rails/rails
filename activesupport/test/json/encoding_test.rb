# encoding: utf-8
require 'securerandom'
require 'abstract_unit'
require 'active_support/core_ext/string/inflections'
require 'active_support/json'
require 'active_support/time'

class TestJSONEncoding < ActiveSupport::TestCase
  class Foo
    def initialize(a, b)
      @a, @b = a, b
    end
  end

  class Hashlike
    def to_hash
      { :foo => "hello", :bar => "world" }
    end
  end

  class Custom
    def initialize(serialized)
      @serialized = serialized
    end

    def as_json(options = nil)
      @serialized
    end
  end

  class CustomWithOptions
    attr_accessor :foo, :bar

    def as_json(options={})
      options[:only] = %w(foo bar)
      super(options)
    end
  end

  class OptionsTest
    def as_json(options = :default)
      options
    end
  end

  class HashWithAsJson < Hash
    attr_accessor :as_json_called

    def initialize(*)
      super
    end

    def as_json(options={})
      @as_json_called = true
      super
    end
  end

  TrueTests     = [[ true,  %(true)  ]]
  FalseTests    = [[ false, %(false) ]]
  NilTests      = [[ nil,   %(null)  ]]
  NumericTests  = [[ 1,     %(1)     ],
                   [ 2.5,   %(2.5)   ],
                   [ 0.0/0.0,   %(null) ],
                   [ 1.0/0.0,   %(null) ],
                   [ -1.0/0.0,  %(null) ],
                   [ BigDecimal('0.0')/BigDecimal('0.0'),  %(null) ],
                   [ BigDecimal('2.5'), %("#{BigDecimal('2.5').to_s}") ]]

  StringTests   = [[ 'this is the <string>',     %("this is the \\u003cstring\\u003e")],
                   [ 'a "string" with quotes & an ampersand', %("a \\"string\\" with quotes \\u0026 an ampersand") ],
                   [ 'http://test.host/posts/1', %("http://test.host/posts/1")],
                   [ "Control characters: \x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\u2028\u2029",
                     %("Control characters: \\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\b\\t\\n\\u000b\\f\\r\\u000e\\u000f\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001a\\u001b\\u001c\\u001d\\u001e\\u001f\\u2028\\u2029") ]]

  ArrayTests    = [[ ['a', 'b', 'c'],          %([\"a\",\"b\",\"c\"])          ],
                   [ [1, 'a', :b, nil, false], %([1,\"a\",\"b\",null,false]) ]]

  RangeTests    = [[ 1..2,     %("1..2")],
                   [ 1...2,    %("1...2")],
                   [ 1.5..2.5, %("1.5..2.5")]]

  SymbolTests   = [[ :a,     %("a")    ],
                   [ :this,  %("this") ],
                   [ :"a b", %("a b")  ]]

  ObjectTests   = [[ Foo.new(1, 2), %({\"a\":1,\"b\":2}) ]]
  HashlikeTests = [[ Hashlike.new, %({\"bar\":\"world\",\"foo\":\"hello\"}) ]]
  CustomTests   = [[ Custom.new("custom"), '"custom"' ],
                   [ Custom.new(nil), 'null' ],
                   [ Custom.new(:a), '"a"' ],
                   [ Custom.new([ :foo, "bar" ]), '["foo","bar"]' ],
                   [ Custom.new({ :foo => "hello", :bar => "world" }), '{"bar":"world","foo":"hello"}' ],
                   [ Custom.new(Hashlike.new), '{"bar":"world","foo":"hello"}' ],
                   [ Custom.new(Custom.new(Custom.new(:a))), '"a"' ]]

  RegexpTests   = [[ /^a/, '"(?-mix:^a)"' ], [/^\w{1,2}[a-z]+/ix, '"(?ix-m:^\\\\w{1,2}[a-z]+)"']]

  DateTests     = [[ Date.new(2005,2,1), %("2005/02/01") ]]
  TimeTests     = [[ Time.utc(2005,2,1,15,15,10), %("2005/02/01 15:15:10 +0000") ]]
  DateTimeTests = [[ DateTime.civil(2005,2,1,15,15,10), %("2005/02/01 15:15:10 +0000") ]]

  StandardDateTests     = [[ Date.new(2005,2,1), %("2005-02-01") ]]
  StandardTimeTests     = [[ Time.utc(2005,2,1,15,15,10), %("2005-02-01T15:15:10.000Z") ]]
  StandardDateTimeTests = [[ DateTime.civil(2005,2,1,15,15,10), %("2005-02-01T15:15:10.000+00:00") ]]
  StandardStringTests   = [[ 'this is the <string>', %("this is the <string>")]]

  def sorted_json(json)
    return json unless json =~ /^\{.*\}$/
    '{' + json[1..-2].split(',').sort.join(',') + '}'
  end

  constants.grep(/Tests$/).each do |class_tests|
    define_method("test_#{class_tests[0..-6].underscore}") do
      begin
        prev = ActiveSupport.use_standard_json_time_format

        ActiveSupport.escape_html_entities_in_json  = class_tests !~ /^Standard/
        ActiveSupport.use_standard_json_time_format = class_tests =~ /^Standard/
        self.class.const_get(class_tests).each do |pair|
          assert_equal pair.last, sorted_json(ActiveSupport::JSON.encode(pair.first))
        end
      ensure
        ActiveSupport.escape_html_entities_in_json  = false
        ActiveSupport.use_standard_json_time_format = prev
      end
    end
  end

  def test_process_status
    # There doesn't seem to be a good way to get a handle on a Process::Status object without actually
    # creating a child process, hence this to populate $?
    system("not_a_real_program_#{SecureRandom.hex}")
    assert_equal %({"exitstatus":#{$?.exitstatus},"pid":#{$?.pid}}), ActiveSupport::JSON.encode($?)
  end

  def test_hash_encoding
    assert_equal %({\"a\":\"b\"}), ActiveSupport::JSON.encode(:a => :b)
    assert_equal %({\"a\":1}), ActiveSupport::JSON.encode('a' => 1)
    assert_equal %({\"a\":[1,2]}), ActiveSupport::JSON.encode('a' => [1,2])
    assert_equal %({"1":2}), ActiveSupport::JSON.encode(1 => 2)

    assert_equal %({\"a\":\"b\",\"c\":\"d\"}), sorted_json(ActiveSupport::JSON.encode(:a => :b, :c => :d))
  end

  def test_hash_keys_encoding
    ActiveSupport.escape_html_entities_in_json = true
    assert_equal "{\"\\u003c\\u003e\":\"\\u003c\\u003e\"}", ActiveSupport::JSON.encode("<>" => "<>")
  ensure
    ActiveSupport.escape_html_entities_in_json = false
  end

  def test_utf8_string_encoded_properly
    result = ActiveSupport::JSON.encode('€2.99')
    assert_equal '"€2.99"', result
    assert_equal(Encoding::UTF_8, result.encoding)

    result = ActiveSupport::JSON.encode('✎☺')
    assert_equal '"✎☺"', result
    assert_equal(Encoding::UTF_8, result.encoding)
  end

  def test_non_utf8_string_transcodes
    s = '二'.encode('Shift_JIS')
    result = ActiveSupport::JSON.encode(s)
    assert_equal '"二"', result
    assert_equal Encoding::UTF_8, result.encoding
  end

  def test_wide_utf8_chars
    w = '𠜎'
    result = ActiveSupport::JSON.encode(w)
    assert_equal '"𠜎"', result
  end

  def test_wide_utf8_roundtrip
    hash = { string: "𐒑" }
    json = ActiveSupport::JSON.encode(hash)
    decoded_hash = ActiveSupport::JSON.decode(json)
    assert_equal "𐒑", decoded_hash['string']
  end

  def test_reading_encode_big_decimal_as_string_option
    assert_deprecated do
      assert ActiveSupport.encode_big_decimal_as_string
    end
  end

  def test_setting_deprecated_encode_big_decimal_as_string_option
    assert_raise(NotImplementedError) do
      ActiveSupport.encode_big_decimal_as_string = true
    end

    assert_raise(NotImplementedError) do
      ActiveSupport.encode_big_decimal_as_string = false
    end
  end

  def test_exception_raised_when_encoding_circular_reference_in_array
    a = [1]
    a << a
    assert_deprecated do
      assert_raise(ActiveSupport::JSON::Encoding::CircularReferenceError) { ActiveSupport::JSON.encode(a) }
    end
  end

  def test_exception_raised_when_encoding_circular_reference_in_hash
    a = { :name => 'foo' }
    a[:next] = a
    assert_deprecated do
      assert_raise(ActiveSupport::JSON::Encoding::CircularReferenceError) { ActiveSupport::JSON.encode(a) }
    end
  end

  def test_exception_raised_when_encoding_circular_reference_in_hash_inside_array
    a = { :name => 'foo', :sub => [] }
    a[:sub] << a
    assert_deprecated do
      assert_raise(ActiveSupport::JSON::Encoding::CircularReferenceError) { ActiveSupport::JSON.encode(a) }
    end
  end

  def test_hash_key_identifiers_are_always_quoted
    values = {0 => 0, 1 => 1, :_ => :_, "$" => "$", "a" => "a", :A => :A, :A0 => :A0, "A0B" => "A0B"}
    assert_equal %w( "$" "A" "A0" "A0B" "_" "a" "0" "1" ).sort, object_keys(ActiveSupport::JSON.encode(values))
  end

  def test_hash_should_allow_key_filtering_with_only
    assert_equal %({"a":1}), ActiveSupport::JSON.encode({'a' => 1, :b => 2, :c => 3}, :only => 'a')
  end

  def test_hash_should_allow_key_filtering_with_except
    assert_equal %({"b":2}), ActiveSupport::JSON.encode({'foo' => 'bar', :b => 2, :c => 3}, :except => ['foo', :c])
  end

  def test_time_to_json_includes_local_offset
    with_standard_json_time_format(true) do
      with_env_tz 'US/Eastern' do
        assert_equal %("2005-02-01T15:15:10.000-05:00"), ActiveSupport::JSON.encode(Time.local(2005,2,1,15,15,10))
      end
    end
  end

  def test_hash_with_time_to_json
    with_standard_json_time_format(false) do
      assert_equal '{"time":"2009/01/01 00:00:00 +0000"}', { :time => Time.utc(2009) }.to_json
    end
  end

  def test_nested_hash_with_float
    assert_nothing_raised do
      hash = {
        "CHI" => {
          :display_name => "chicago",
          :latitude => 123.234
        }
      }
      ActiveSupport::JSON.encode(hash)
    end
  end

  def test_hash_like_with_options
    h = Hashlike.new
    json = h.to_json :only => [:foo]

    assert_equal({"foo"=>"hello"}, JSON.parse(json))
  end

  def test_object_to_json_with_options
    obj = Object.new
    obj.instance_variable_set :@foo, "hello"
    obj.instance_variable_set :@bar, "world"
    json = obj.to_json :only => ["foo"]

    assert_equal({"foo"=>"hello"}, JSON.parse(json))
  end

  def test_struct_to_json_with_options
    struct = Struct.new(:foo, :bar).new
    struct.foo = "hello"
    struct.bar = "world"
    json = struct.to_json :only => [:foo]

    assert_equal({"foo"=>"hello"}, JSON.parse(json))
  end

  def test_hash_should_pass_encoding_options_to_children_in_as_json
    person = {
      :name => 'John',
      :address => {
        :city => 'London',
        :country => 'UK'
      }
    }
    json = person.as_json :only => [:address, :city]

    assert_equal({ 'address' => { 'city' => 'London' }}, json)
  end

  def test_hash_should_pass_encoding_options_to_children_in_to_json
    person = {
      :name => 'John',
      :address => {
        :city => 'London',
        :country => 'UK'
      }
    }
    json = person.to_json :only => [:address, :city]

    assert_equal(%({"address":{"city":"London"}}), json)
  end

  def test_array_should_pass_encoding_options_to_children_in_as_json
    people = [
      { :name => 'John', :address => { :city => 'London', :country => 'UK' }},
      { :name => 'Jean', :address => { :city => 'Paris' , :country => 'France' }}
    ]
    json = people.as_json :only => [:address, :city]
    expected = [
      { 'address' => { 'city' => 'London' }},
      { 'address' => { 'city' => 'Paris' }}
    ]

    assert_equal(expected, json)
  end

  def test_array_should_pass_encoding_options_to_children_in_to_json
    people = [
      { :name => 'John', :address => { :city => 'London', :country => 'UK' }},
      { :name => 'Jean', :address => { :city => 'Paris' , :country => 'France' }}
    ]
    json = people.to_json :only => [:address, :city]

    assert_equal(%([{"address":{"city":"London"}},{"address":{"city":"Paris"}}]), json)
  end

  def test_enumerable_should_pass_encoding_options_to_children_in_as_json
    people = [
      { :name => 'John', :address => { :city => 'London', :country => 'UK' }},
      { :name => 'Jean', :address => { :city => 'Paris' , :country => 'France' }}
    ]
    json = people.each.as_json :only => [:address, :city]
    expected = [
      { 'address' => { 'city' => 'London' }},
      { 'address' => { 'city' => 'Paris' }}
    ]

    assert_equal(expected, json)
  end

  def test_enumerable_should_pass_encoding_options_to_children_in_to_json
    people = [
      { :name => 'John', :address => { :city => 'London', :country => 'UK' }},
      { :name => 'Jean', :address => { :city => 'Paris' , :country => 'France' }}
    ]
    json = people.each.to_json :only => [:address, :city]

    assert_equal(%([{"address":{"city":"London"}},{"address":{"city":"Paris"}}]), json)
  end

  def test_hash_to_json_should_not_keep_options_around
    f = CustomWithOptions.new
    f.foo = "hello"
    f.bar = "world"

    hash = {"foo" => f, "other_hash" => {"foo" => "other_foo", "test" => "other_test"}}
    assert_equal({"foo"=>{"foo"=>"hello","bar"=>"world"},
                  "other_hash" => {"foo"=>"other_foo","test"=>"other_test"}}, ActiveSupport::JSON.decode(hash.to_json))
  end

  def test_array_to_json_should_not_keep_options_around
    f = CustomWithOptions.new
    f.foo = "hello"
    f.bar = "world"

    array = [f, {"foo" => "other_foo", "test" => "other_test"}]
    assert_equal([{"foo"=>"hello","bar"=>"world"},
                  {"foo"=>"other_foo","test"=>"other_test"}], ActiveSupport::JSON.decode(array.to_json))
  end

  def test_hash_as_json_without_options
    json = { foo: OptionsTest.new }.as_json
    assert_equal({"foo" => :default}, json)
  end

  def test_array_as_json_without_options
    json = [ OptionsTest.new ].as_json
    assert_equal([:default], json)
  end

  def test_struct_encoding
    Struct.new('UserNameAndEmail', :name, :email)
    Struct.new('UserNameAndDate', :name, :date)
    Struct.new('Custom', :name, :sub)
    user_email = Struct::UserNameAndEmail.new 'David', 'sample@example.com'
    user_birthday = Struct::UserNameAndDate.new 'David', Date.new(2010, 01, 01)
    custom = Struct::Custom.new 'David', user_birthday


    json_strings = ""
    json_string_and_date = ""
    json_custom = ""

    assert_nothing_raised do
      json_strings = user_email.to_json
      json_string_and_date = user_birthday.to_json
      json_custom = custom.to_json
    end

    assert_equal({"name" => "David",
                  "sub" => {
                    "name" => "David",
                    "date" => "2010-01-01" }}, ActiveSupport::JSON.decode(json_custom))

    assert_equal({"name" => "David", "email" => "sample@example.com"},
                 ActiveSupport::JSON.decode(json_strings))

    assert_equal({"name" => "David", "date" => "2010-01-01"},
                 ActiveSupport::JSON.decode(json_string_and_date))
  end

  def test_nil_true_and_false_represented_as_themselves
    assert_equal nil,   nil.as_json
    assert_equal true,  true.as_json
    assert_equal false, false.as_json
  end

  def test_json_gem_dump_by_passing_active_support_encoder
    h = HashWithAsJson.new
    h[:foo] = "hello"
    h[:bar] = "world"

    assert_equal %({"foo":"hello","bar":"world"}), JSON.dump(h)
    assert_nil h.as_json_called
  end

  def test_json_gem_generate_by_passing_active_support_encoder
    h = HashWithAsJson.new
    h[:foo] = "hello"
    h[:bar] = "world"

    assert_equal %({"foo":"hello","bar":"world"}), JSON.generate(h)
    assert_nil h.as_json_called
  end

  def test_json_gem_pretty_generate_by_passing_active_support_encoder
    h = HashWithAsJson.new
    h[:foo] = "hello"
    h[:bar] = "world"

    assert_equal <<EXPECTED.chomp, JSON.pretty_generate(h)
{
  "foo": "hello",
  "bar": "world"
}
EXPECTED
    assert_nil h.as_json_called
  end

  def test_twz_to_json_with_use_standard_json_time_format_config_set_to_false
    with_standard_json_time_format(false) do
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      time = ActiveSupport::TimeWithZone.new(Time.utc(2000), zone)
      assert_equal "\"1999/12/31 19:00:00 -0500\"", ActiveSupport::JSON.encode(time)
    end
  end

  def test_twz_to_json_with_use_standard_json_time_format_config_set_to_true
    with_standard_json_time_format(true) do
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      time = ActiveSupport::TimeWithZone.new(Time.utc(2000), zone)
      assert_equal "\"1999-12-31T19:00:00.000-05:00\"", ActiveSupport::JSON.encode(time)
    end
  end

  def test_twz_to_json_with_custom_time_precision
    with_standard_json_time_format(true) do
      ActiveSupport::JSON::Encoding.time_precision = 0
      zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      time = ActiveSupport::TimeWithZone.new(Time.utc(2000), zone)
      assert_equal "\"1999-12-31T19:00:00-05:00\"", ActiveSupport::JSON.encode(time)
    end
  ensure
    ActiveSupport::JSON::Encoding.time_precision = 3
  end

  def test_time_to_json_with_custom_time_precision
    with_standard_json_time_format(true) do
      ActiveSupport::JSON::Encoding.time_precision = 0
      assert_equal "\"2000-01-01T00:00:00Z\"", ActiveSupport::JSON.encode(Time.utc(2000))
    end
  ensure
    ActiveSupport::JSON::Encoding.time_precision = 3
  end

  def test_datetime_to_json_with_custom_time_precision
    with_standard_json_time_format(true) do
      ActiveSupport::JSON::Encoding.time_precision = 0
      assert_equal "\"2000-01-01T00:00:00+00:00\"", ActiveSupport::JSON.encode(DateTime.new(2000))
    end
  ensure
    ActiveSupport::JSON::Encoding.time_precision = 3
  end

  def test_twz_to_json_when_wrapping_a_date_time
    zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    time = ActiveSupport::TimeWithZone.new(DateTime.new(2000), zone)
    assert_equal '"1999-12-31T19:00:00.000-05:00"', ActiveSupport::JSON.encode(time)
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

    def with_standard_json_time_format(boolean = true)
      old, ActiveSupport.use_standard_json_time_format = ActiveSupport.use_standard_json_time_format, boolean
      yield
    ensure
      ActiveSupport.use_standard_json_time_format = old
    end
end
