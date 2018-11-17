# frozen_string_literal: true

module ToBoolean
  FALSE_VALUES = [nil, false, 0, 0.0, "", "0", "f", "F", "false", "FALSE", "off", "OFF", [], {}].to_set

  # Returns a boolean value, according the object value.
  #
  def to_bool
    !FALSE_VALUES.include?(self)
  end
end

# Add the to_bool behaviour to all the follow classes:
#
class String; include ToBoolean; end
class Integer; include ToBoolean; end
class Float; include ToBoolean; end
class Array; include ToBoolean; end
class Hash; include ToBoolean; end
class TrueClass; include ToBoolean; end
class FalseClass; include ToBoolean; end
class NilClass; include ToBoolean; end
