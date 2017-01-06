module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Jsonb < Json # :nodoc:
          def type
            :jsonb
          end

          def changed_in_place?(raw_old_value, new_value)
            # Postgres does not preserve insignificant whitespaces or key order when
            # round-tripping jsonb columns. This causes some false positives for
            # the comparison here. Therefore, we need to parse and re-dump the
            # raw value here to ensure the insignificant whitespaces are
            # consistent with our encoder's output and that the serialized values
            # aren't affected by key order.

            raw_old_value = serialize(sort_json_hash_keys(deserialize(raw_old_value)))
            new_value     = sort_json_hash_keys(new_value)
            super(raw_old_value, new_value)
          end

          private
            def sort_json_hash_keys(parsed_json)
              case parsed_json
              when ::Array
                parsed_json.map { |item| sort_json_hash_keys(item) }
              when ::Hash
                ::Hash[parsed_json.sort]
              else
                parsed_json
              end
            end
        end
      end
    end
  end
end
