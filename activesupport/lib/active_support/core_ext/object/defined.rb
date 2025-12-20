# frozen_string_literal: true

class Object
  # An object is defined if it's not nil.
  #
  # @return [true, false]
  def defined?
    !nil?
  end
end
