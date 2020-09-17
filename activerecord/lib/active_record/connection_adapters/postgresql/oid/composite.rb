# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Composite < Type::Value # :nodoc:
          include Quoting
          attr_reader :delim, :attributes

          # +delim+ corresponds to the `typdelim` column in the pg_types table.
          # +attributes+ contains the list of attribute definitions from the
          # pg_attribute table in a form of hash with `:name` and `:type` keys.
          def initialize(delim, attributes)
            @delim = delim
            @attributes = attributes
          end

          def cast(value)
            parts = _parts(value)
            return if parts.blank?

            attributes.zip(parts).each_with_object({}) do |(attr, part), obj|
              obj[attr[:name]] = attr[:type].cast(part)
            end
          end

          def serialize(value)
            return value if value.is_a?(String)
            return unless value.respond_to?(:to_h)

            value = value.symbolize_keys
            parts = attributes.map do |attr|
              part = attr[:type].serialize(value[attr[:name]])
              # Multiply quotation marks in the nested tuple to escape them,
              # and wrap this nested tuple by itself into double quotation marks.
              attr[:type].is_a?(self.class) ? "\"#{part.gsub('"', '""')}\"" : part
            end

            "(#{parts.join(delim)})"
          end

          # Represent values in the schema as postgres tuples
          alias type_cast_for_schema serialize

          private

          # Names of attributes of the composite type
          def _names
            @_names ||= attributes.map { |attr| attr[:name] }
          end

          # Extract parts of the composite value
          # from either string or hash-like structures:
          def _parts(value)
            if value.is_a?(String)
              _split_tuple value.gsub(/\A[^(]*\(|\)[^)]*\z/, "")
            elsif value.respond_to?(:to_h)
              value.to_h.symbolize_keys.values_at(*_names)
            end
          end

          # Regex to select unnested chunks surrounded by any brackets
          CHUNKS = /\([^()]*\)|\[[^\[\]]*\]|\{[^{}]*\}/.freeze

          # Parse string like "(foo,(bar,baz)),qux" to return a string "$1,qux"
          # along with array of chunks like ["(bar,baz)","(foo,$0)"]
          def _parse(value, chunks = [])
            new_chunks = chunks + value.scan(CHUNKS)
            return [value, chunks] if new_chunks == chunks

            new_value = value.dup
            new_chunks.each_with_index { |chunk, num| new_value.gsub!(chunk, "$#{num}") }
            _parse(new_value, new_chunks)
          end

          # Split tuple like '"(foo,"(bar,baz)")",qux' to upper-level parts only
          # like ['(foo,"(bar,baz)")', 'qux']
          def _split_tuple(value)
            value, chunks = _parse(value)
            pairs = chunks.each.with_index.reverse_each
            # Drop quotation marks around nested tuples
            parts = value.split(delim).map { |part| part.gsub(/\A"+|"+\z/, "") }
            parts.each { |part| pairs.each { |(c, i)| part.gsub!("$#{i}", c) } }
          end
        end
      end
    end
  end
end
