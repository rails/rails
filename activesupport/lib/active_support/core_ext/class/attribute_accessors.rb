require 'active_support/deprecation'
require 'active_support/core_ext/module/attribute_accessors'

ActiveSupport::Deprecation.warn(
  "The cattr_* method definitions have been moved into active_support/core_ext/module/attribute_accessors. Please require that instead."
)
