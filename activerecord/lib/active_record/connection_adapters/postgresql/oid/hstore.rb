# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Hstore < Type::Value # :nodoc:
          include ActiveModel::Type::Helpers::Mutable

          def type
            :hstore
          end

          def deserialize(value)
            if value.is_a?(::String)
              ::Hash[value.scan(HstorePair).map { |k, v|
                v = v.upcase == 'NULL' ? nil : v.gsub(/\A"(.*)"\Z/m, '\1').gsub(/\\(.)/, '\1')
                k = k.gsub(/\A"(.*)"\Z/m, '\1').gsub(/\\(.)/, '\1')
                [k, v]
              }]
            else
              value
            end
          end

          def serialize(value)
            if value.is_a?(::Hash)
              value.map { |k, v| "#{escape_hstore(k)}=>#{escape_hstore(v)}" }.join(', ')
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
            HstorePair = begin
              quoted_string = /"[^"\\]*(?:\\.[^"\\]*)*"/
              unquoted_string = /(?:\\.|[^\s,])[^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
              /(#{quoted_string}|#{unquoted_string})\s*=>\s*(#{quoted_string}|#{unquoted_string})/
            end

            def escape_hstore(value)
              if value.nil?
                'NULL'
              else
                if value == ''
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
