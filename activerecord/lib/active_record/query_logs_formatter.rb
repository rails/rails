# frozen_string_literal: true

module ActiveRecord
  module QueryLogs
    module LegacyFormatter # :nodoc:
      class << self
        # Formats the key value pairs into a string.
        def format(key, value)
          "#{key}:#{value}"
        end

        def join(pairs)
          pairs.join(",")
        end
      end
    end

    class SQLCommenter # :nodoc:
      class << self
        def format(key, value)
          "#{key}='#{ERB::Util.url_encode(value)}'"
        end

        def join(pairs)
          pairs.join(",")
        end
      end
    end
  end
end
