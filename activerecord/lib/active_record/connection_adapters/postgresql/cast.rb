module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLColumn < Column
      module Cast
        def string_to_time(string)
          return string unless String === string

          case string
          when 'infinity'; 1.0 / 0.0
          when '-infinity'; -1.0 / 0.0
          else
            super
          end
        end

        def hstore_to_string(object)
          if Hash === object
            object.map { |k,v|
              "#{escape_hstore(k)}=>#{escape_hstore(v)}"
            }.join ','
          else
            object
          end
        end

        def string_to_hstore(string)
          if string.nil?
            nil
          elsif String === string
            Hash[string.scan(HstorePair).map { |k,v|
              v = v.upcase == 'NULL' ? nil : v.gsub(/^"(.*)"$/,'\1').gsub(/\\(.)/, '\1')
              k = k.gsub(/^"(.*)"$/,'\1').gsub(/\\(.)/, '\1')
              [k,v]
            }]
          else
            string
          end
        end

        def json_to_string(object)
          if Hash === object
            ActiveSupport::JSON.encode(object)
          else
            object
          end
        end

        def array_to_string(value, column, adapter, should_be_quoted = false)
          casted_values = value.map do |val|
            if String === val
              if val == "NULL"
                "\"#{val}\""
              else
                quote_and_escape(adapter.type_cast(val, column, true))
              end
            else
              adapter.type_cast(val, column, true)
            end
          end
          "{#{casted_values.join(',')}}"
        end

        def string_to_json(string)
          if String === string
            ActiveSupport::JSON.decode(string)
          else
            string
          end
        end

        def string_to_cidr(string)
          if string.nil?
            nil
          elsif String === string
            IPAddr.new(string)
          else
            string
          end
        end

        def cidr_to_string(object)
          if IPAddr === object
            "#{object.to_s}/#{object.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
          else
            object
          end
        end

        def string_to_array(string, oid)
          parse_pg_array(string).map{|val| oid.type_cast val}
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
              if value == ""
                '""'
              else
                '"%s"' % value.to_s.gsub(/(["\\])/, '\\\\\1')
              end
            end
          end

          def quote_and_escape(value)
            case value
            when "NULL"
              value
            else
              "\"#{value.gsub(/"/,"\\\"")}\""
            end
          end
      end
    end
  end
end
