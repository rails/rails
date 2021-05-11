# frozen_string_literal: true

require "strscan"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Hstore < Type::Value # :nodoc:
          ERROR = "Invalid Hstore document: %s"

          include ActiveModel::Type::Helpers::Mutable

          def type
            :hstore
          end

          def deserialize(value)
            return value unless value.is_a?(::String)

            scanner = StringScanner.new(value)
            hash = {}

            until scanner.eos?
              unless scanner.skip(/"/)
                raise(ArgumentError, ERROR % scanner.string.inspect)
              end

              unless key = scanner.scan_until(/(?<!\\)(?=")/)
                raise(ArgumentError, ERROR % scanner.string.inspect)
              end

              unless scanner.skip(/"=>?/)
                raise(ArgumentError, ERROR % scanner.string.inspect)
              end

              if scanner.scan(/NULL/)
                value = nil
              else
                unless scanner.skip(/"/)
                  raise(ArgumentError, ERROR % scanner.string.inspect)
                end

                unless value = scanner.scan_until(/(?<!\\)(?=")/)
                  raise(ArgumentError, ERROR % scanner.string.inspect)
                end

                unless scanner.skip(/"/)
                  raise(ArgumentError, ERROR % scanner.string.inspect)
                end
              end

              key.gsub!('\"', '"')
              key.gsub!('\\\\', '\\')

              if value
                value.gsub!('\"', '"')
                value.gsub!('\\\\', '\\')
              end

              hash[key] = value

              unless scanner.skip(/, /) || scanner.eos?
                raise(ArgumentError, ERROR % scanner.string.inspect)
              end
            end

            hash
          end

          def serialize(value)
            if value.is_a?(::Hash)
              value.map { |k, v| "#{escape_hstore(k)}=>#{escape_hstore(v)}" }.join(", ")
            elsif value.respond_to?(:to_unsafe_h)
              serialize(value.to_unsafe_h)
            else
              value
            end
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end

          # Will compare the Hash equivalents of +raw_old_value+ and +new_value+.
          # By comparing hashes, this avoids an edge case where the order of
          # the keys change between the two hashes, and they would not be marked
          # as equal.
          def changed_in_place?(raw_old_value, new_value)
            deserialize(raw_old_value) != new_value
          end

          private
            def escape_hstore(value)
              if value.nil?
                "NULL"
              else
                if value == ""
                  '""'
                else
                  '"%s"' % value.to_s.gsub(/(["\\])/, '\\\\\1')
                end
              end
            end
        end
      end
    end
  end
end
