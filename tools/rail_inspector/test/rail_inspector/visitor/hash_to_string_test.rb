# frozen_string_literal: true

require "test_helper"
require "rail_inspector/visitor/hash_to_string"

class HashToStringTest < Minitest::Test
  def test_basic_hash_to_s
    basic_hash = "{ a: 1 }"

    assert_equal basic_hash, string_for(basic_hash)
  end

  def test_nested_hash_to_s
    nested_hash = "{ hsts: { subdomains: true } }"

    assert_equal nested_hash, string_for(nested_hash)
  end

  def test_string_keys_to_s
    string_keys =
      '{ "X-Frame-Options" => "SAMEORIGIN", "X-XSS-Protection" => "0", "X-Content-Type-Options" => "nosniff", "X-Permitted-Cross-Domain-Policies" => "none", "Referrer-Policy" => "strict-origin-when-cross-origin" }'

    assert_equal string_keys, string_for(string_keys)
  end

  private
    def string_for(hash_as_string)
      ast = Prism.parse(hash_as_string).value
      visitor = RailInspector::Visitor::HashToString.new
      visitor.visit(ast)
      visitor.to_s
    end
end
