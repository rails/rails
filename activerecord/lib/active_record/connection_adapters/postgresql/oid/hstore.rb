module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Hstore < Type::Value # :nodoc:
          include Type::Helpers::Mutable

          def type
            :hstore
          end

          def deserialize(value)
            if value.is_a?(::String)
              ::Hash[value.scan(HstorePair).map { |k, v|
                v = v.upcase == "NULL" ? nil : v.gsub(/\A"(.*)"\Z/m, '\1').gsub(/\\(.)/, '\1')
                k = k.gsub(/\A"(.*)"\Z/m, '\1').gsub(/\\(.)/, '\1')
                [k, v]
              }]
            else
              value
            end
          end

          def serialize(value)
            if value.is_a?(::Hash)
              value.map { |k, v| "#{escape_hstore(k)}=>#{escape_hstore(v)}" }.join(", ")
            else
              value
            end
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end

          private

            HstorePair = begin
              quoted_string = /"[^"\\]*(?:\\.[^"\\]*)*"/
              unquoted_string = /(?:\\.|[^\s,])[^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
              /(#{quoted_string}|#{unquoted_string})\s*=>\s*(#{quoted_string}|#{unquoted_string})/
            end

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
