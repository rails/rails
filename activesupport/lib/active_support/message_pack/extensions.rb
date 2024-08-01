# frozen_string_literal: true

require "bigdecimal"
require "date"
require "ipaddr"
require "pathname"
require "uri/generic"
require "msgpack/bigint"
require "active_support/hash_with_indifferent_access"
require "active_support/time"

module ActiveSupport
  module MessagePack
    class UnserializableObjectError < StandardError; end
    class MissingClassError < StandardError; end # :nodoc:

    module Extensions # :nodoc:
      extend self

      def install(registry)
        registry.register_type 0, Symbol,
          packer: :to_msgpack_ext,
          unpacker: :from_msgpack_ext,
          optimized_symbols_parsing: true

        registry.register_type 1, Integer,
          packer: ::MessagePack::Bigint.method(:to_msgpack_ext),
          unpacker: ::MessagePack::Bigint.method(:from_msgpack_ext),
          oversized_integer_extension: true

        registry.register_type 2, BigDecimal,
          packer: :_dump,
          unpacker: :_load

        registry.register_type 3, Rational,
          packer: method(:write_rational),
          unpacker: method(:read_rational),
          recursive: true

        registry.register_type 4, Complex,
          packer: method(:write_complex),
          unpacker: method(:read_complex),
          recursive: true

        registry.register_type 5, DateTime,
          packer: method(:write_datetime),
          unpacker: method(:read_datetime),
          recursive: true

        registry.register_type 6, Date,
          packer: method(:write_date),
          unpacker: method(:read_date),
          recursive: true

        registry.register_type 7, Time,
          packer: method(:write_time),
          unpacker: method(:read_time),
          recursive: true

        registry.register_type 8, ActiveSupport::TimeWithZone,
          packer: method(:write_time_with_zone),
          unpacker: method(:read_time_with_zone),
          recursive: true

        registry.register_type 9, ActiveSupport::TimeZone,
          packer: method(:dump_time_zone),
          unpacker: method(:load_time_zone)

        registry.register_type 10, ActiveSupport::Duration,
          packer: method(:write_duration),
          unpacker: method(:read_duration),
          recursive: true

        registry.register_type 11, Range,
          packer: method(:write_range),
          unpacker: method(:read_range),
          recursive: true

        registry.register_type 12, Set,
          packer: method(:write_set),
          unpacker: method(:read_set),
          recursive: true

        registry.register_type 13, URI::Generic,
          packer: :to_s,
          unpacker: URI.method(:parse)

        registry.register_type 14, IPAddr,
          packer: method(:write_ipaddr),
          unpacker: method(:read_ipaddr),
          recursive: true

        registry.register_type 15, Pathname,
          packer: :to_s,
          unpacker: :new

        registry.register_type 16, Regexp,
          packer: :to_s,
          unpacker: :new

        registry.register_type 17, ActiveSupport::HashWithIndifferentAccess,
          packer: method(:write_hash_with_indifferent_access),
          unpacker: method(:read_hash_with_indifferent_access),
          recursive: true
      end

      def install_unregistered_type_error(registry)
        registry.register_type 127, Object,
          packer: method(:raise_unserializable),
          unpacker: method(:raise_invalid_format)
      end

      def install_unregistered_type_fallback(registry)
        registry.register_type 127, Object,
          packer: method(:write_object),
          unpacker: method(:read_object),
          recursive: true
      end

      def write_rational(rational, packer)
        packer.write(rational.numerator)
        packer.write(rational.denominator) unless rational.numerator.zero?
      end

      def read_rational(unpacker)
        numerator = unpacker.read
        Rational(numerator, numerator.zero? ? 1 : unpacker.read)
      end

      def write_complex(complex, packer)
        packer.write(complex.real)
        packer.write(complex.imaginary)
      end

      def read_complex(unpacker)
        Complex(unpacker.read, unpacker.read)
      end

      def write_datetime(datetime, packer)
        packer.write(datetime.jd)
        packer.write(datetime.hour)
        packer.write(datetime.min)
        packer.write(datetime.sec)
        write_rational(datetime.sec_fraction, packer)
        write_rational(datetime.offset, packer)
      end

      def read_datetime(unpacker)
        DateTime.jd(unpacker.read, unpacker.read, unpacker.read, unpacker.read + read_rational(unpacker), read_rational(unpacker))
      end

      def write_date(date, packer)
        packer.write(date.jd)
      end

      def read_date(unpacker)
        Date.jd(unpacker.read)
      end

      def write_time(time, packer)
        packer.write(time.tv_sec)
        packer.write(time.tv_nsec)
        packer.write(time.utc_offset)
      end

      def read_time(unpacker)
        Time.at_without_coercion(unpacker.read, unpacker.read, :nanosecond, in: unpacker.read)
      end

      def write_time_with_zone(twz, packer)
        write_time(twz.utc, packer)
        write_time_zone(twz.time_zone, packer)
      end

      def read_time_with_zone(unpacker)
        ActiveSupport::TimeWithZone.new(read_time(unpacker), read_time_zone(unpacker))
      end

      def dump_time_zone(time_zone)
        time_zone.name
      end

      def load_time_zone(name)
        ActiveSupport::TimeZone[name]
      end

      def write_time_zone(time_zone, packer)
        packer.write(dump_time_zone(time_zone))
      end

      def read_time_zone(unpacker)
        load_time_zone(unpacker.read)
      end

      def write_duration(duration, packer)
        packer.write(duration.value)
        packer.write(duration._parts.values_at(*ActiveSupport::Duration::PARTS))
      end

      def read_duration(unpacker)
        value = unpacker.read
        parts = ActiveSupport::Duration::PARTS.zip(unpacker.read).to_h
        parts.compact!
        ActiveSupport::Duration.new(value, parts)
      end

      def write_range(range, packer)
        packer.write(range.begin)
        packer.write(range.end)
        packer.write(range.exclude_end?)
      end

      def read_range(unpacker)
        Range.new(unpacker.read, unpacker.read, unpacker.read)
      end

      def write_set(set, packer)
        packer.write(set.to_a)
      end

      def read_set(unpacker)
        Set.new(unpacker.read)
      end

      def write_ipaddr(ipaddr, packer)
        if ipaddr.prefix < 32 || (ipaddr.ipv6? && ipaddr.prefix < 128)
          packer.write("#{ipaddr}/#{ipaddr.prefix}")
        else
          packer.write(ipaddr.to_s)
        end
      end

      def read_ipaddr(unpacker)
        IPAddr.new(unpacker.read)
      end

      def write_hash_with_indifferent_access(hwia, packer)
        packer.write(hwia.to_h)
      end

      def read_hash_with_indifferent_access(unpacker)
        ActiveSupport::HashWithIndifferentAccess.new(unpacker.read)
      end

      def raise_unserializable(object, *)
        raise UnserializableObjectError, "Unsupported type #{object.class} for object #{object.inspect}"
      end

      def raise_invalid_format(*)
        raise "Invalid format"
      end

      def dump_class(klass)
        raise UnserializableObjectError, "Cannot serialize anonymous class" unless klass.name
        klass.name
      end

      def load_class(name)
        Object.const_get(name)
      rescue NameError => error
        if error.name.to_s == name
          raise MissingClassError, "Missing class: #{name}"
        else
          raise
        end
      end

      def write_class(klass, packer)
        packer.write(dump_class(klass))
      end

      def read_class(unpacker)
        load_class(unpacker.read)
      end

      LOAD_WITH_MSGPACK_EXT = 0
      LOAD_WITH_JSON_CREATE = 1

      def write_object(object, packer)
        if object.class.respond_to?(:from_msgpack_ext)
          packer.write(LOAD_WITH_MSGPACK_EXT)
          write_class(object.class, packer)
          packer.write(object.to_msgpack_ext)
        elsif object.class.respond_to?(:json_create)
          packer.write(LOAD_WITH_JSON_CREATE)
          write_class(object.class, packer)
          packer.write(object.as_json)
        else
          raise_unserializable(object)
        end
      end

      def read_object(unpacker)
        case unpacker.read
        when LOAD_WITH_MSGPACK_EXT
          read_class(unpacker).from_msgpack_ext(unpacker.read)
        when LOAD_WITH_JSON_CREATE
          read_class(unpacker).json_create(unpacker.read)
        else
          raise_invalid_format
        end
      end
    end
  end
end
