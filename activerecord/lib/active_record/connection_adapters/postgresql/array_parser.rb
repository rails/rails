module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLColumn < Column
      module ArrayParser
        private
          # Loads pg_array_parser if available. String parsing can be
          # performed quicker by a native extension, which will not create
          # a large amount of Ruby objects that will need to be garbage
          # collected. pg_array_parser has a C and Java extension
          begin
            require 'pg_array_parser'
            include PgArrayParser
          rescue LoadError
            def parse_pg_array(string)
              parse_data(string, 0)
            end
          end

          def parse_data(string, index)
            local_index = index
            array = []
            while(local_index < string.length)
              case string[local_index]
              when '{'
                local_index,array = parse_array_contents(array, string, local_index + 1)
              when '}'
                return array
              end
              local_index += 1
            end

            array
          end

          def parse_array_contents(array, string, index)
            is_escaping = false
            is_quoted = false
            was_quoted = false
            current_item = ''

            local_index = index
            while local_index
              token = string[local_index]
              if is_escaping
                current_item << token
                is_escaping = false
              else
                if is_quoted
                  case token
                  when '"'
                    is_quoted = false
                    was_quoted = true
                  when "\\"
                    is_escaping = true
                  else
                    current_item << token
                  end
                else
                  case token
                  when "\\"
                    is_escaping = true
                  when ','
                    add_item_to_array(array, current_item, was_quoted)
                    current_item = ''
                    was_quoted = false
                  when '"'
                    is_quoted = true
                  when '{'
                    internal_items = []
                    local_index,internal_items = parse_array_contents(internal_items, string, local_index + 1)
                    array.push(internal_items)
                  when '}'
                    add_item_to_array(array, current_item, was_quoted)
                    return local_index,array
                  else
                    current_item << token
                  end
                end
              end

              local_index += 1
            end
            return local_index,array
          end

          def add_item_to_array(array, current_item, quoted)
            if current_item.length == 0
            elsif !quoted && current_item == 'NULL'
              array.push nil
            else
              array.push current_item
            end
          end
      end
    end
  end
end
