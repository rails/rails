# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/base32"

class ActiveSupport::Base32::CrockfordTest < ActiveSupport::TestCase
  test "generate returns a string of the requested length" do
    assert_equal 6, ActiveSupport::Base32::Crockford.generate(6).length
  end

  test "generate defaults to 16 characters" do
    assert_equal 16, ActiveSupport::Base32::Crockford.generate.length
  end

  test "generate returns unique values" do
    assert_not_equal ActiveSupport::Base32::Crockford.generate, ActiveSupport::Base32::Crockford.generate
  end

  test "generate only contains Crockford Base32 characters" do
    code = ActiveSupport::Base32::Crockford.generate(100)
    assert_match(/\A[0-9A-HJKMNP-TV-Z]+\z/, code)
  end

  test "normalize upcases input" do
    assert_equal "ABC123", ActiveSupport::Base32::Crockford.normalize("abc 123")
  end

  test "normalize substitutes O to 0" do
    assert_equal "0", ActiveSupport::Base32::Crockford.normalize("O")
  end

  test "normalize substitutes I to 1" do
    assert_equal "1", ActiveSupport::Base32::Crockford.normalize("I")
  end

  test "normalize substitutes L to 1" do
    assert_equal "1", ActiveSupport::Base32::Crockford.normalize("L")
  end

  test "normalize strips invalid characters" do
    assert_equal "011123", ActiveSupport::Base32::Crockford.normalize("OIL-123")
  end

  test "normalize returns nil for nil" do
    assert_nil ActiveSupport::Base32::Crockford.normalize(nil)
  end

  test "normalize returns nil for empty string" do
    assert_nil ActiveSupport::Base32::Crockford.normalize("")
  end

  test "normalize returns nil for whitespace-only string" do
    assert_nil ActiveSupport::Base32::Crockford.normalize("   ")
  end

  test "normalize returns nil for only invalid characters" do
    assert_nil ActiveSupport::Base32::Crockford.normalize("---")
  end
end
