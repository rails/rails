# frozen_string_literal: true

module ToBoolean
  # Returns a boolean value, according the Object type and value.
  # Uses the active model role to define the result
  #
  def to_bool
    return false unless self
    ActiveModel::Type::Boolean.new.cast(self)
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
