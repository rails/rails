require 'active_support/core_ext/module/remove_possible_method'

class Module
  def redefine_method(method, &block)
    remove_possible_method(method)
    define_method(method, &block)
  end
end
