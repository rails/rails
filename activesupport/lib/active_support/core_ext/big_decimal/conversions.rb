require 'bigdecimal'
require 'bigdecimal/util'

class BigDecimal
  DEFAULT_STRING_FORMAT = 'F'
  alias_method :to_default_s, :to_s

  def to_s(format = nil, options = nil)
    if format.is_a?(Symbol)
      to_formatted_s(format, options || {})
    else
      to_default_s(format || DEFAULT_STRING_FORMAT)
    end
  end
end
