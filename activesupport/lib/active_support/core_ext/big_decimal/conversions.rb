require 'bigdecimal'
require 'bigdecimal/util'

class BigDecimal
  DEFAULT_STRING_FORMAT = 'F'
  def to_formatted_s(*args)
    if args[0].is_a?(Symbol)
      super
    else
      format = args[0] || DEFAULT_STRING_FORMAT
      _original_to_s(format)
    end
  end
  alias_method :_original_to_s, :to_s
  alias_method :to_s, :to_formatted_s
end
