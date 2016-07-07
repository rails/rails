module ActiveSupport::RangeWithFormat
  RANGE_FORMATS = {
    :db => Proc.new { |start, stop| "BETWEEN '#{start.to_s(:db)}' AND '#{stop.to_s(:db)}'" }
  }

  # Convert range to a formatted string. See RANGE_FORMATS for predefined formats.
  #
  #   range = (1..100)           # => 1..100
  #
  #   range.to_s                 # => "1..100"
  #   range.to_s(:db)            # => "BETWEEN '1' AND '100'"
  #
  # == Adding your own range formats to to_s
  # You can add your own formats to the Range::RANGE_FORMATS hash.
  # Use the format name as the hash key and a Proc instance.
  #
  #   # config/initializers/range_formats.rb
  #   Range::RANGE_FORMATS[:short] = ->(start, stop) { "Between #{start.to_s(:db)} and #{stop.to_s(:db)}" }
  def to_s(format = :default)
    if formatter = RANGE_FORMATS[format]
      formatter.call(first, last)
    else
      super()
    end
  end

  alias_method :to_default_s, :to_s
  alias_method :to_formatted_s, :to_s
end

Range.prepend(ActiveSupport::RangeWithFormat)
