require 'bigdecimal'
require 'bigdecimal/util'
require 'yaml'

class BigDecimal
  YAML_MAPPING = { 'Infinity' => '.Inf', '-Infinity' => '-.Inf', 'NaN' => '.NaN' }

  def encode_with(coder)
    string = to_s
    coder.represent_scalar(nil, YAML_MAPPING[string] || string)
  end

  # Backport this method if it doesn't exist
  unless method_defined?(:to_d)
    def to_d
      self
    end
  end

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
