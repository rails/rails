# :markup: markdown
# frozen_string_literal: true

module ActiveSupport
  # \Range With Format
  # ==================
  module RangeWithFormat
    RANGE_FORMATS = {
      db: -> (range) do
        start, stop = range.begin, range.end
        exclusive = range.exclude_end?

        format_bound = ->(value) do
          case value
          when String then value
          else value.to_fs(:db)
          end
        end

        if start && stop
          if exclusive
            ">= '#{format_bound[start]}' AND < '#{format_bound[stop]}'"
          else
            "BETWEEN '#{format_bound[start]}' AND '#{format_bound[stop]}'"
          end
        elsif start
          ">= '#{format_bound[start]}'"
        elsif stop
          if exclusive
            "< '#{format_bound[stop]}'"
          else
            "<= '#{format_bound[stop]}'"
          end
        end
      end
    }.freeze

    # Converts the range to a formatted string. See RANGE_FORMATS for predefined formats.
    #
    # This method is aliased to `to_formatted_s`.
    #
    # ```ruby
    # range = (1..100)           # => 1..100
    #
    # range.to_s                 # => "1..100"
    # range.to_fs(:db)           # => "BETWEEN '1' AND '100'"
    #
    # range = (1...100)          # => 1...100
    # range.to_fs(:db)           # => ">= '1' AND < '100'"
    #
    # range = (1..)              # => 1..
    # range.to_fs(:db)           # => ">= '1'"
    #
    # range = (..100)            # => ..100
    # range.to_fs(:db)           # => "<= '100'"
    #
    # range = (...100)           # => ...100
    # range.to_fs(:db)           # => "< '100'"
    # ```
    #
    # ## Adding your own range formats to `to_fs`
    #
    # You can add your own formats to the Range::RANGE_FORMATS hash.
    # Use the format name as the hash key and a Proc instance.
    # The proc receives the range.
    #
    # ```ruby
    # # config/initializers/range_formats.rb
    # Range::RANGE_FORMATS[:short] = ->(range) { "Between #{range.begin.to_fs(:db)} and #{range.end.to_fs(:db)}" }
    # ```
    def to_fs(format = :default)
      if formatter = RANGE_FORMATS[format]
        formatter.call(self)
      else
        to_s
      end
    end
    alias_method :to_formatted_s, :to_fs
  end
end

Range.prepend(ActiveSupport::RangeWithFormat)
