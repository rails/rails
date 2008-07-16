module ActiveModel
  class Base
    include Observing
    # disabled, until they're tested
    # include Callbacks
    # include Validations
  end
end