module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ArrayParser # :nodoc:

        DOUBLE_QUOTE = '"'
        BACKSLASH = "\\"
        COMMA = ','
        BRACKET_OPEN = '{'
        BRACKET_CLOSE = '}'

        def parse_pg_array(string) # :nodoc:
          local_index = 0
          array = []
          while(local_index < string.length)
            case string[local_index]
            when BRACKET_OPEN
              local_index,array = parse_array_contents(array, string, local_index + 1)
            when BRACKET_CLOSE
              return array
            end
            local_index += 1
          end

          array
        end

        private

          def parse_array_contents(array, string, index)
            is_escaping  = false
            is_quoted    = false
            was_quoted   = false
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
                  when DOUBLE_QUOTE
                    is_quoted = false
                    was_quoted = true
                  when BACKSLASH
                    is_escaping = true
                  else
                    current_item << token
                  end
                else
                  case token
                  when BACKSLASH
                    is_escaping = true
                  when COMMA
                    add_item_to_array(array, current_item, was_quoted)
                    current_item = ''
                    was_quoted = false
                  when DOUBLE_QUOTE
                    is_quoted = true
                  when BRACKET_OPEN
                    internal_items = []
                    local_index,internal_items = parse_array_contents(internal_items, string, local_index + 1)
                    array.push(internal_items)
                  when BRACKET_CLOSE
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
            return if !quoted && current_item.length == 0

            if !quoted && current_item == 'NULL'
              array.push nil
            else
              array.push current_item
            end
          end
      end
    end
  end
end
