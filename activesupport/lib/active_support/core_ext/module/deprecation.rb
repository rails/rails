require 'active_support/deprecation'

class Module
  # Declare that a method has been deprecated.
  #   deprecate :foo
  #   deprecate :bar => 'message'
  #   deprecate :foo, :bar, :baz => 'warning!', :qux => 'gone!'
  def deprecate(*method_names)
    ActiveSupport::Deprecation.deprecate_methods(self, *method_names)
  end
end
