require "abstract_unit"
require "active_support/ordered_hash"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/string/output_safety"

class ToQueryTest < ActiveSupport::TestCase
  def test_simple_conversion
    assert_query_equal "a=10", a: 10
  end

  def test_cgi_escaping
    assert_query_equal "a%3Ab=c+d", "a:b" => "c d"
  end

  def test_html_safe_parameter_key
    assert_query_equal "a%3Ab=c+d", "a:b".html_safe => "c d"
  end

  def test_html_safe_parameter_value
    assert_query_equal "a=%5B10%5D", "a" => "[10]".html_safe
  end

  def test_nil_parameter_value
    empty = Object.new
    def empty.to_param; nil end
    assert_query_equal "a=", "a" => empty
  end

  def test_nested_conversion
    assert_query_equal "person%5Blogin%5D=seckar&person%5Bname%5D=Nicholas",
      person: Hash[:login, "seckar", :name, "Nicholas"]
  end

  def test_multiple_nested
    assert_query_equal "account%5Bperson%5D%5Bid%5D=20&person%5Bid%5D=10",
      Hash[:account, { person: { id: 20 } }, :person, { id: 10 }]
  end

  def test_array_values
    assert_query_equal "person%5Bid%5D%5B%5D=10&person%5Bid%5D%5B%5D=20",
      person: { id: [10, 20] }
  end

  def test_array_values_are_not_sorted
    assert_query_equal "person%5Bid%5D%5B%5D=20&person%5Bid%5D%5B%5D=10",
      person: { id: [20, 10] }
  end

  def test_empty_array
    assert_equal "person%5B%5D=", [].to_query("person")
  end

  def test_nested_empty_hash
    assert_equal "",
      {}.to_query
    assert_query_equal "a=1&b%5Bc%5D=3",
      a: 1, b: { c: 3, d: {} }
    assert_query_equal "",
      a: { b: { c: {} } }
    assert_query_equal "b%5Bc%5D=false&b%5Be%5D=&b%5Bf%5D=&p=12",
      p: 12, b: { c: false, e: nil, f: "" }
    assert_query_equal "b%5Bc%5D=3&b%5Bf%5D=",
      b: { c: 3, k: {}, f: "" }
    assert_query_equal "b=3",
      a: [], b: 3
  end

  def test_hash_with_namespace
    hash = { name: "Nakshay", nationality: "Indian" }
    assert_equal "user%5Bname%5D=Nakshay&user%5Bnationality%5D=Indian", hash.to_query("user")
  end

  def test_hash_sorted_lexicographically
    hash = { type: "human", name: "Nakshay" }
    assert_equal "name=Nakshay&type=human", hash.to_query
  end

  def test_hash_not_sorted_lexicographically_for_nested_structure
    params = {
      "foo" => {
        "contents" => [
          { "name" => "gorby", "id" => "123" },
          { "name" => "puff", "d" => "true" }
        ]
      }
    }
    expected = "foo[contents][][name]=gorby&foo[contents][][id]=123&foo[contents][][name]=puff&foo[contents][][d]=true"

    assert_equal expected, URI.decode(params.to_query)
  end

  private
    def assert_query_equal(expected, actual)
      assert_equal expected.split("&"), actual.to_query.split("&")
    end
end
