module I18n
  module Backend
    module Helpers
      SEPARATOR_ESCAPE_CHAR = "\001"

      # Return a new hash with all keys and nested keys converted to symbols.
      def deep_symbolize_keys(hash)
        hash.inject({}) { |result, (key, value)|
          value = deep_symbolize_keys(value) if value.is_a?(Hash)
          result[(key.to_sym rescue key) || key] = value
          result
        }
      end

      # Flatten keys for nested Hashes by chaining up keys using the separator
      #   >> { "a" => { "b" => { "c" => "d", "e" => "f" }, "g" => "h" }, "i" => "j"}.wind
      #   => { "a.b.c" => "d", "a.b.e" => "f", "a.g" => "h", "i" => "j" }
      def wind_keys(hash, separator = nil, subtree = false, prev_key = nil, result = {}, orig_hash=hash)
        separator ||= I18n.default_separator

        hash.each_pair do |key, value|
          key = escape_default_separator(key, separator)
          curr_key = [prev_key, key].compact.join(separator).to_sym

          if value.is_a?(Hash)
            result[curr_key] = value if subtree
            wind_keys(value, separator, subtree, curr_key, result, orig_hash)
          else
            result[unescape_default_separator(curr_key)] = value
          end
        end

        result
      end

      def escape_default_separator(key, separator=nil)
        key.to_s.tr(separator || I18n.default_separator, SEPARATOR_ESCAPE_CHAR)
      end
      
      def unescape_default_separator(key, separator=nil)
        key.to_s.tr(SEPARATOR_ESCAPE_CHAR, separator || I18n.default_separator).to_sym
      end

      # Expand keys chained by the the given separator through nested Hashes
      #   >> { "a.b.c" => "d", "a.b.e" => "f", "a.g" => "h", "i" => "j" }.unwind
      #   => { "a" => { "b" => { "c" => "d", "e" => "f" }, "g" => "h" }, "i" => "j"}
      def unwind_keys(hash, separator = ".")
        result = {}
        hash.each do |key, value|
          keys = key.to_s.split(separator)
          curr = result
          curr = curr[keys.shift] ||= {} while keys.size > 1
          curr[keys.shift] = value
        end
        result
      end

      # # Flatten the given array once
      # def flatten_once(array)
      #   result = []
      #   for element in array # a little faster than each
      #     result.push(*element)
      #   end
      #   result
      # end
    end
  end
end
