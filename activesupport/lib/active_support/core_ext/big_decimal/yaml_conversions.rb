ActiveSupport::Deprecation.warn 'core_ext/big_decimal/yaml_conversions is deprecated and will be removed in the future.'

require 'bigdecimal'
require 'yaml'
require 'active_support/core_ext/big_decimal/conversions'

class BigDecimal
  YAML_MAPPING = { 'Infinity' => '.Inf', '-Infinity' => '-.Inf', 'NaN' => '.NaN' }

  def encode_with(coder)
    string = to_s
    coder.represent_scalar(nil, YAML_MAPPING[string] || string)
  end
end
