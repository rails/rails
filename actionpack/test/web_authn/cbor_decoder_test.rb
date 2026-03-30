# frozen_string_literal: true

require_relative "../web_authn_test_helper"

class ActionPack::WebAuthn::CborDecoderTest < ActiveSupport::TestCase
  test "decodes unsigned integer 0" do
    assert_equal 0, decode("00")
  end

  test "decodes unsigned integer 1" do
    assert_equal 1, decode("01")
  end

  test "decodes unsigned integer 10" do
    assert_equal 10, decode("0a")
  end

  test "decodes unsigned integer 23" do
    assert_equal 23, decode("17")
  end

  test "decodes unsigned integer 24 (single byte follows)" do
    assert_equal 24, decode("1818")
  end

  test "decodes unsigned integer 25" do
    assert_equal 25, decode("1819")
  end

  test "decodes unsigned integer 100" do
    assert_equal 100, decode("1864")
  end

  test "decodes unsigned integer 1000 (two bytes follow)" do
    assert_equal 1000, decode("1903e8")
  end

  test "decodes unsigned integer 1000000 (four bytes follow)" do
    assert_equal 1000000, decode("1a000f4240")
  end

  test "decodes unsigned integer 1000000000000 (eight bytes follow)" do
    assert_equal 1000000000000, decode("1b000000e8d4a51000")
  end

  test "decodes negative integer -1" do
    assert_equal(-1, decode("20"))
  end

  test "decodes negative integer -10" do
    assert_equal(-10, decode("29"))
  end

  test "decodes negative integer -100" do
    assert_equal(-100, decode("3863"))
  end

  test "decodes negative integer -1000" do
    assert_equal(-1000, decode("3903e7"))
  end

  test "decodes empty byte string" do
    assert_equal "", decode("40")
  end

  test "decodes byte string with 4 bytes" do
    assert_equal "\x01\x02\x03\x04".b, decode("4401020304")
  end

  test "decodes empty text string" do
    result = decode("60")
    assert_equal "", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  test "decodes text string 'a'" do
    result = decode("6161")
    assert_equal "a", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  test "decodes text string 'IETF'" do
    result = decode("6449455446")
    assert_equal "IETF", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  test "decodes text string with unicode" do
    result = decode("62c3bc")
    assert_equal "ü", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  test "decodes empty array" do
    assert_equal [], decode("80")
  end

  test "decodes array [1, 2, 3]" do
    assert_equal [ 1, 2, 3 ], decode("83010203")
  end

  test "decodes nested array [1, [2, 3], [4, 5]]" do
    assert_equal [ 1, [ 2, 3 ], [ 4, 5 ] ], decode("8301820203820405")
  end

  test "decodes array with 25 elements" do
    expected = (1..25).to_a
    # 0x9819 = array with 25 elements (0x98 = type 4 + additional 24, 0x19 = 25)
    # integers 1-23 encode as single bytes, 24 = 0x1818, 25 = 0x1819
    elements = (1..23).map { |n| format("%02x", n) }.join + "18181819"
    assert_equal expected, decode("9819" + elements)
  end

  test "decodes empty map" do
    assert_equal({}, decode("a0"))
  end

  test "decodes map {1: 2, 3: 4}" do
    assert_equal({ 1 => 2, 3 => 4 }, decode("a201020304"))
  end

  test "decodes map with string keys" do
    assert_equal({ "a" => 1, "b" => 2 }, decode("a2616101616202"))
  end

  test "decodes nested map" do
    assert_equal({ "a" => { "b" => 1 } }, decode("a16161a1616201"))
  end

  test "decodes false" do
    assert_equal false, decode("f4")
  end

  test "decodes true" do
    assert_equal true, decode("f5")
  end

  test "decodes null" do
    assert_nil decode("f6")
  end

  test "decodes undefined as nil" do
    assert_nil decode("f7")
  end

  test "decodes tagged value, ignoring tag" do
    # 0xc0 = tag 0 (date/time string), followed by text "2013-03-21T20:04:00Z"
    assert_equal "2013-03-21T20:04:00Z", decode("c074323031332d30332d32315432303a30343a30305a")
  end

  test "decodes tagged integer" do
    # 0xc1 = tag 1 (epoch time), followed by integer 1363896240
    assert_equal 1363896240, decode("c11a514b67b0")
  end

  test "raises error for reserved additional info values" do
    assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      decode("1c")
    end
  end

  test "decodes indefinite length array" do
    assert_equal [ 1, 2, 3 ], decode("9f010203ff")
  end

  test "decodes empty indefinite length array" do
    assert_equal [], decode("9fff")
  end

  test "decodes empty indefinite length map" do
    assert_equal({}, decode("bfff"))
  end

  test "decodes indefinite length map" do
    assert_equal({ "a" => 1, "b" => 2 }, decode("bf616101616202ff"))
  end

  test "decodes indefinite length byte string" do
    assert_equal "\x01\x02\x03".b, decode("5f4201024103ff")
  end

  test "decodes indefinite length text string" do
    result = decode("7f657374726561646d696e67ff")
    assert_equal "streaming", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  test "decodes half-precision float 0.0" do
    assert_equal 0.0, decode("f90000")
  end

  test "decodes half-precision float 1.0" do
    assert_equal 1.0, decode("f93c00")
  end

  test "decodes half-precision float 1.5" do
    assert_equal 1.5, decode("f93e00")
  end

  test "decodes half-precision float -4.0" do
    assert_equal(-4.0, decode("f9c400"))
  end

  test "decodes half-precision positive infinity" do
    assert_equal Float::INFINITY, decode("f97c00")
  end

  test "decodes half-precision NaN" do
    assert_predicate decode("f97e00"), :nan?
  end

  test "decodes single-precision float 100000.0" do
    assert_equal 100000.0, decode("fa47c35000")
  end

  test "decodes single-precision positive infinity" do
    assert_equal Float::INFINITY, decode("fa7f800000")
  end

  test "decodes double-precision float 1.1" do
    assert_in_delta 1.1, decode("fb3ff199999999999a"), 0.0001
  end

  test "decodes double-precision float -4.1" do
    assert_in_delta(-4.1, decode("fbc010666666666666"), 0.0001)
  end

  test "decodes double-precision positive infinity" do
    assert_equal Float::INFINITY, decode("fb7ff0000000000000")
  end

  test "decodes double-precision negative infinity" do
    assert_equal(-Float::INFINITY, decode("fbfff0000000000000"))
  end

  test "raises error for unsupported simple value" do
    assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      decode("e0")
    end
  end

  test "decode accepts string input" do
    bytes = [ 0x01 ].pack("C*")
    assert_equal 1, ActionPack::WebAuthn::CborDecoder.decode(bytes)
  end

  test "decode accepts array input" do
    assert_equal 1, ActionPack::WebAuthn::CborDecoder.decode([ 0x01 ])
  end

  test "raises error for empty input" do
    assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      ActionPack::WebAuthn::CborDecoder.decode([])
    end
  end

  test "raises error for truncated byte string" do
    # 0x44 = byte string of length 4, but only 2 bytes follow
    assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      decode("440102")
    end
  end

  test "raises error for truncated integer" do
    # 0x19 = 2-byte integer follows, but only 1 byte provided
    assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      decode("19ff")
    end
  end

  test "raises error for truncated array" do
    # 0x82 = array of 2 items, but only 1 provided
    assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      decode("8201")
    end
  end

  test "raises error for deeply nested structure" do
    # Build array nested 20 levels deep: [[[[...]]]]
    # 0x81 = array of 1 item
    deeply_nested = "81" * 20 + "01"

    error = assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      decode(deeply_nested)
    end

    assert_equal "Maximum nesting depth exceeded", error.message
  end

  test "raises error for input exceeding max size" do
    error = assert_raises(ActionPack::WebAuthn::InvalidCborError) do
      ActionPack::WebAuthn::CborDecoder.decode([ 0x01 ], max_size: 0)
    end

    assert_equal "Input exceeds maximum size", error.message
  end

  private
    def decode(hex)
      bytes = [ hex ].pack("H*").bytes
      ActionPack::WebAuthn::CborDecoder.decode(bytes)
    end
end
