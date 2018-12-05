# frozen_string_literal: true

class Object
  # Includes a module into the singleton class of an object
  def include(mod)
    self.singleton_class.include(mod)
  end
end