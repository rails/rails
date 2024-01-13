# frozen_string_literal: true

module MessagePackSharedSerializerTests
  extend ActiveSupport::Concern

  included do
    test "enshrines type IDs" do
      expected = {
        0   => Symbol,
        1   => Integer,
        2   => BigDecimal,
        3   => Rational,
        4   => Complex,
        5   => DateTime,
        6   => Date,
        7   => Time,
        8   => ActiveSupport::TimeWithZone,
        9   => ActiveSupport::TimeZone,
        10  => ActiveSupport::Duration,
        11  => Range,
        12  => Set,
        13  => URI::Generic,
        14  => IPAddr,
        15  => Pathname,
        16  => Regexp,
        17  => ActiveSupport::HashWithIndifferentAccess,
        127 => Object,
      }

      serializer.warmup
      actual = serializer.message_pack_factory.registered_types.to_h do |entry|
        [entry[:type], entry[:class]]
      end

      assert_equal expected, actual
    end

    test "includes signature in message" do
      assert serializer.signature?(dump(""))
      assert_not serializer.signature?(Marshal.dump(""))
      assert_not serializer.signature?("{}")
    end

    test "#signature? handles non-ASCII-only non-binary-encoded strings" do
      assert serializer.signature?(dump("ümlaut").force_encoding(Encoding::UTF_8))
      assert_not serializer.signature?("ümlaut")
    end

    test "roundtrips Symbol" do
      assert_roundtrip :some_symbol
    end

    test "roundtrips very large Integer" do
      assert_roundtrip 2**512
    end

    test "roundtrips BigDecimal" do
      assert_roundtrip BigDecimal("9876543210.0123456789")
    end

    test "roundtrips Rational" do
      assert_roundtrip Rational(1, 3)
    end

    test "optimizes Rational zero encoding" do
      assert_roundtrip Rational(0, 1)

      serialized_zero = dump(Rational(0, 1))
      serialized_nonzero = dump(Rational(1, 1))
      assert_operator serialized_zero.size, :<, serialized_nonzero.size
    end

    test "roundtrips Complex" do
      assert_roundtrip Complex(1, -1)
    end

    test "roundtrips DateTime" do
      assert_roundtrip DateTime.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), Rational(-1, 2))
      assert_roundtrip DateTime.now
    end

    test "roundtrips Date" do
      assert_roundtrip Date.new(1999, 12, 31)
      assert_roundtrip Date.today
    end

    test "roundtrips Time" do
      assert_roundtrip Time.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), "-12:00")
      assert_roundtrip Time.now
    end

    test "roundtrips ActiveSupport::TimeWithZone" do
      assert_roundtrip ActiveSupport::TimeWithZone.new(
        Time.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), "UTC"),
        ActiveSupport::TimeZone["Australia/Lord_Howe"]
      )
      assert_roundtrip Time.current
    end

    test "roundtrips ActiveSupport::TimeZone" do
      assert_roundtrip ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    test "roundtrips ActiveSupport::Duration" do
      assert_roundtrip 1.year + 2.months + 3.weeks + 4.days + 5.hours + 6.minutes + 7.seconds
      assert_roundtrip 1.month + 1.day
    end

    test "roundtrips Range" do
      assert_roundtrip 1..2
      assert_roundtrip 1...2
      assert_roundtrip 1..nil
      assert_roundtrip 1...nil
      assert_roundtrip nil..2
      assert_roundtrip nil...2
      assert_roundtrip "1".."2"
      assert_roundtrip "1"..."2"
    end

    test "roundtrips Set" do
      assert_roundtrip Set.new([nil, true, 2, "three"])
    end

    test "roundtrips URI::Generic" do
      assert_roundtrip URI("https://example.com/#test")
    end

    test "roundtrips IPAddr" do
      assert_roundtrip IPAddr.new("127.0.0.1")
      assert_roundtrip IPAddr.new("1.1.1.1/16")
      assert_equal 16, load(dump(IPAddr.new("1.1.1.1/16"))).prefix

      assert_roundtrip IPAddr.new("::1")
      assert_roundtrip IPAddr.new("1:1:1:1:1:1:1:1/64")
      assert_equal 64, load(dump(IPAddr.new("1:1:1:1:1:1:1:1/64"))).prefix
    end

    test "roundtrips Pathname" do
      assert_roundtrip Pathname(__FILE__)
    end

    test "roundtrips Regexp" do
      assert_roundtrip %r/(?m-ix:.*)/
    end

    test "roundtrips ActiveSupport::HashWithIndifferentAccess" do
      assert_roundtrip ActiveSupport::HashWithIndifferentAccess.new(a: true, b: 2, c: "three")
    end

    test "works with ENV['RAILS_MAX_THREADS']" do
      original_env = ENV.to_h
      ENV["RAILS_MAX_THREADS"] = "1"

      assert_roundtrip "value"
    ensure
      ENV.replace(original_env)
    end
  end

  private
    def dump(object)
      serializer.dump(object)
    end

    def load(dumped)
      serializer.load(dumped)
    end

    def assert_roundtrip(object)
      serialized = dump(object)
      assert_kind_of String, serialized

      deserialized = load(serialized)
      assert_instance_of object.class, deserialized
      assert_equal object, deserialized
    end
end
