# frozen_string_literal: true

class RaisesNoMethodError
  Object.new.calling_a_non_existing_method
end
