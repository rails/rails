require "securerandom"
require "abstract_unit"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/regexp"
require "active_support/json"
require "active_support/time"
require "time_zone_test_helpers"
require "json/encoding_test_cases"

class TestJSONEncoding < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def sorted_json(json)
    if json.start_with?("{") && json.end_with?("}")
      "{" + json[1..-2].split(",").sort.join(",") + "}"
    else
      json
    end
  end

  JSONTest::EncodingTestCases.constants.each do |class_tests|
    define_method("test_#{class_tests[0..-6].underscore}") do
      begin
        prev = ActiveSupport.use_standard_json_time_format

        standard_class_tests = /Standard/.match?(class_tests)

        ActiveSupport.escape_html_entities_in_json  = !standard_class_tests
        ActiveSupport.use_standard_json_time_format = standard_class_tests
        JSONTest::EncodingTestCases.const_get(class_tests).each do |pair|
          assert_equal pair.last, sorted_json(ActiveSupport::JSON.encode(pair.first))
        end
      ensure
        ActiveSupport.escape_html_entities_in_json  = false
        ActiveSupport.use_standard_json_time_format = prev
      end
    end
  end

  def test_process_status
    rubinius_skip "https://github.com/rubinius/rubinius/issues/3334"

    # There doesn't seem to be a good way to get a handle on a Process::Status object without actually
    # creating a child process, hence this to populate $?
    system("not_a_real_program_#{SecureRandom.hex}")
    assert_equal %({"exitstatus":#{$?.exitstatus},"pid":#{$?.pid}}), ActiveSupport::JSON.encode($?)
  end

  def test_hash_encoding
    assert_equal %({\"a\":\"b\"}), ActiveSupport::JSON.encode(a: :b)
    assert_equal %({\"a\":1}), ActiveSupport::JSON.encode("a" => 1)
    assert_equal %({\"a\":[1,2]}), ActiveSupport::JSON.encode("a" => [1, 2])
    assert_equal %({"1":2}), ActiveSupport::JSON.encode(1 => 2)

    assert_equal %({\"a\":\"b\",\"c\":\"d\"}), sorted_json(ActiveSupport::JSON.encode(a: :b, c: :d))
  end

  def test_hash_keys_encoding
    ActiveSupport.escape_html_entities_in_json = true
    assert_equal "{\"\\u003c\\u003e\":\"\\u003c\\u003e\"}", ActiveSupport::JSON.encode("<>" => "<>")
  ensure
    ActiveSupport.escape_html_entities_in_json = false
  end

  def test_utf8_string_encoded_properly
    result = ActiveSupport::JSON.encode("€2.99")
    assert_equal '"€2.99"', result
    assert_equal(Encoding::UTF_8, result.encoding)

    result = ActiveSupport::JSON.encode("✎☺")
    assert_equal '"✎☺"', result
    assert_equal(Encoding::UTF_8, result.encoding)
  end

  def test_non_utf8_string_transcodes
    s = "二".encode("Shift_JIS")
    result = ActiveSupport::JSON.encode(s)
    assert_equal '"二"', result
    assert_equal Encoding::UTF_8, result.encoding
  end

  def test_wide_utf8_chars
    w = "𠜎"
    result = ActiveSupport::JSON.encode(w)
    assert_equal '"𠜎"', result
  end

  def test_wide_utf8_roundtrip
    hash = { string: "𐒑" }
    json = ActiveSupport::JSON.encode(hash)
    decoded_hash = ActiveSupport::JSON.decode(json)
    assert_equal "𐒑", decoded_hash["string"]
  end

  def test_hash_key_identifiers_are_always_quoted
    values = { 0 => 0, 1 => 1, :_ => :_, "$" => "$", "a" => "a", :A => :A, :A0 => :A0, "A0B" => "A0B" }
    assert_equal %w( "$" "A" "A0" "A0B" "_" "a" "0" "1" ).sort, object_keys(ActiveSupport::JSON.encode(values))
  end

  def test_hash_should_allow_key_filtering_with_only
    assert_equal %({"a":1}), ActiveSupport::JSON.encode({ "a" => 1, :b => 2, :c => 3 }, only: "a")
  end

  def test_hash_should_allow_key_filtering_with_except
    assert_equal %({"b":2}), ActiveSupport::JSON.encode({ "foo" => "bar", :b => 2, :c => 3 }, except: ["foo", :c])
  end

  def test_time_to_json_includes_local_offset
    with_standard_json_time_format(true) do
      with_env_tz "US/Eastern" do
        assert_equal %("2005-02-01T15:15:10.000-05:00"), ActiveSupport::JSON.encode(Time.local(2005, 2, 1, 15, 15, 10))
      end
    end
  end

  def test_hash_with_time_to_json
    with_standard_json_time_format(false) do
      assert_equal '{"time":"2009/01/01 00:00:00 +0000"}', { time: Time.utc(2009) }.to_json
    end
  end

  def test_nested_hash_with_float
    assert_nothing_raised do
      hash = {
        "CHI" => {
          display_name: "chicago",
          latitude: 123.234
        }
      }
      ActiveSupport::JSON.encode(hash)
    end
  end

  def test_hash_like_with_options
    h = JSONTest::Hashlike.new
    json = h.to_json only: [:foo]

    assert_equal({ "foo" => "hello" }, JSON.parse(json))
  end

  def test_object_to_json_with_options
    obj = Object.new
    obj.instance_variable_set :@foo, "hello"
    obj.instance_variable_set :@bar, "world"
    json = obj.to_json only: ["foo"]

    assert_equal({ "foo" => "hello" }, JSON.parse(json))
  end

  def test_struct_to_json_with_options
    struct = Struct.new(:foo, :bar).new
    struct.foo = "hello"
    struct.bar = "world"
    json = struct.to_json only: [:foo]

    assert_equal({ "foo" => "hello" }, JSON.parse(json))
  end

  def test_hash_should_pass_encoding_options_to_children_in_as_json
    person = {
      name: "John",
      address: {
        city: "London",
        country: "UK"
      }
    }
    json = person.as_json only: [:address, :city]

    assert_equal({ "address" => { "city" => "London" } }, json)
  end

  def test_hash_should_pass_encoding_options_to_children_in_to_json
    person = {
      name: "John",
      address: {
        city: "London",
        country: "UK"
      }
    }
    json = person.to_json only: [:address, :city]

    assert_equal(%({"address":{"city":"London"}}), json)
  end

  def test_array_should_pass_encoding_options_to_children_in_as_json
    people = [
      { name: "John", address: { city: "London", country: "UK" } },
      { name: "Jean", address: { city: "Paris" , country: "France" } }
    ]
    json = people.as_json only: [:address, :city]
    expected = [
      { "address" => { "city" => "London" } },
      { "address" => { "city" => "Paris" } }
    ]

    assert_equal(expected, json)
  end

  def test_array_should_pass_encoding_options_to_children_in_to_json
    people = [
      { name: "John", address: { city: "London", country: "UK" } },
      { name: "Jean", address: { city: "Paris" , country: "France" } }
    ]
    json = people.to_json only: [:address, :city]

    assert_equal(%([{"address":{"city":"London"}},{"address":{"city":"Paris"}}]), json)
  end

  People = Class.new(BasicObject) do
    include Enumerable
    def initialize()
      @people = [
        { name: "John", address: { city: "London", country: "UK" } },
        { name: "Jean", address: { city: "Paris" , country: "France" } }
      ]
    end
    def each(*, &blk)
      @people.each do |p|
        yield p if blk
        p
      end.each
    end
  end

  def test_enumerable_should_generate_json_with_as_json
    json = People.new.as_json only: [:address, :city]
    expected = [
      { "address" => { "city" => "London" } },
      { "address" => { "city" => "Paris" } }
    ]

    assert_equal(expected, json)
  end

  def test_enumerable_should_generate_json_with_to_json
    json = People.new.to_json only: [:address, :city]
    assert_equal(%([{"address":{"city":"London"}},{"address":{"city":"Paris"}}]), json)
  end

  def test_enumerable_should_pass_encoding_options_to_children_in_as_json
    json = People.new.each.as_json only: [:address, :city]
    expected = [
      { "address" => { "city" => "London" } },
      { "address" => { "city" => "Paris" } }
    ]

    assert_equal(expected, json)
  end

  def test_enumerable_should_pass_encoding_options_to_children_in_to_json
    json = People.new.each.to_json only: [:address, :city]

    assert_equal(%([{"address":{"city":"London"}},{"address":{"city":"Paris"}}]), json)
  end

  class CustomWithOptions
    attr_accessor :foo, :bar

    def as_json(options = {})
      options[:only] = %w(foo bar)
      super(options)
    end
  end

  def test_hash_to_json_should_not_keep_options_around
    f = CustomWithOptions.new
    f.foo = "hello"
    f.bar = "world"

    hash = { "foo" => f, "other_hash" => { "foo" => "other_foo", "test" => "other_test" } }
    assert_equal({ "foo" => { "foo" => "hello", "bar" => "world" },
                  "other_hash" => { "foo" => "other_foo", "test" => "other_test" } }, ActiveSupport::JSON.decode(hash.to_json))
  end

  def test_array_to_json_should_not_keep_options_around
    f = CustomWithOptions.new
    f.foo = "hello"
    f.bar = "world"

    array = [f, { "foo" => "other_foo", "test" => "other_test" }]
    assert_equal([{ "foo" => "hello", "bar" => "world" },
                  { "foo" => "other_foo", "test" => "other_test" }], ActiveSupport::JSON.decode(array.to_json))
  end

  class OptionsTest
    def as_json(options = :default)
      options
    end
  end

  def test_hash_as_json_without_options
    json = { foo: OptionsTest.new }.as_json
    assert_equal({ "foo" => :default }, json)
  end

  def test_array_as_json_without_options
    json = [ OptionsTest.new ].as_json
    assert_equal([:default], json)
  end

  def test_struct_encoding
    Struct.new("UserNameAndEmail", :name, :email)
    Struct.new("UserNameAndDate", :name, :date)
    Struct.new("Custom", :name, :sub)
    user_email = Struct::UserNameAndEmail.new "David", "sample@example.com"
    user_birthday = Struct::UserNameAndDate.new "David", Date.new(2010, 01, 01)
    custom = Struct::Custom.new "David", user_birthday

    json_strings = ""
    json_string_and_date = ""
    json_custom = ""

    assert_nothing_raised do
      json_strings = user_email.to_json
      json_string_and_date = user_birthday.to_json
      json_custom = custom.to_json
    end

    assert_equal({ "name" => "David",
                  "sub" => {
                    "name" => "David",
                    "date" => "2010-01-01" } }, ActiveSupport::JSON.decode(json_custom))

    assert_equal({ "name" => "David", "email" => "sample@example.com" },
                 ActiveSupport::JSON.decode(json_strings))

    assert_equal({ "name" => "David", "date" => "2010-01-01" },
                 ActiveSupport::JSON.decode(json_string_and_date))
  end

  def test_nil_true_and_false_represented_as_themselves
    assert_equal nil,   nil.as_json
    assert_equal true,  true.as_json
    assert_equal false, false.as_json
  end

  class HashWithAsJson < Hash
    attr_accessor :as_json_called

    def initialize(*)
      super
    end

    def as_json(options = {})
      @as_json_called = true
      super
    end
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
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      time = ActiveSupport::TimeWithZone.new(Time.utc(2000), zone)
      assert_equal "\"1999/12/31 19:00:00 -0500\"", ActiveSupport::JSON.encode(time)
    end
  end

  def test_twz_to_json_with_use_standard_json_time_format_config_set_to_true
    with_standard_json_time_format(true) do
      zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      time = ActiveSupport::TimeWithZone.new(Time.utc(2000), zone)
      assert_equal "\"1999-12-31T19:00:00.000-05:00\"", ActiveSupport::JSON.encode(time)
    end
  end

  def test_twz_to_json_with_custom_time_precision
    with_standard_json_time_format(true) do
      with_time_precision(0) do
        zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
        time = ActiveSupport::TimeWithZone.new(Time.utc(2000), zone)
        assert_equal "\"1999-12-31T19:00:00-05:00\"", ActiveSupport::JSON.encode(time)
      end
    end
  end

  def test_time_to_json_with_custom_time_precision
    with_standard_json_time_format(true) do
      with_time_precision(0) do
        assert_equal "\"2000-01-01T00:00:00Z\"", ActiveSupport::JSON.encode(Time.utc(2000))
      end
    end
  end

  def test_datetime_to_json_with_custom_time_precision
    with_standard_json_time_format(true) do
      with_time_precision(0) do
        assert_equal "\"2000-01-01T00:00:00+00:00\"", ActiveSupport::JSON.encode(DateTime.new(2000))
      end
    end
  end

  def test_twz_to_json_when_wrapping_a_date_time
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    time = ActiveSupport::TimeWithZone.new(DateTime.new(2000), zone)
    assert_equal '"1999-12-31T19:00:00.000-05:00"', ActiveSupport::JSON.encode(time)
  end

  def test_exception_to_json
    exception = Exception.new("foo")
    assert_equal '"foo"', ActiveSupport::JSON.encode(exception)
  end

  class InfiniteNumber
    def as_json(options = nil)
      { "number" => Float::INFINITY }
    end
  end

  def test_to_json_works_when_as_json_returns_infinite_number
    assert_equal '{"number":null}', InfiniteNumber.new.to_json
  end

  class NaNNumber
    def as_json(options = nil)
      { "number" => Float::NAN }
    end
  end

  def test_to_json_works_when_as_json_returns_NaN_number
    assert_equal '{"number":null}', NaNNumber.new.to_json
  end

  protected

    def object_keys(json_object)
      json_object[1..-2].scan(/([^{}:,\s]+):/).flatten.sort
    end

    def with_standard_json_time_format(boolean = true)
      old, ActiveSupport.use_standard_json_time_format = ActiveSupport.use_standard_json_time_format, boolean
      yield
    ensure
      ActiveSupport.use_standard_json_time_format = old
    end

    def with_time_precision(value)
      old_value = ActiveSupport::JSON::Encoding.time_precision
      ActiveSupport::JSON::Encoding.time_precision = value
      yield
    ensure
      ActiveSupport::JSON::Encoding.time_precision = old_value
    end
end
