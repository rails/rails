require 'active_support/deprecation/method_wrappers'

class Module
  # Declare that a method has been deprecated.
  #   deprecate :foo
  #   deprecate :bar => 'message'
  #   deprecate :foo, :bar, :baz => 'warning!', :qux => 'gone!'
  # The passed message (if any) will be added to the default deprecation
  # message in parentheses.
  def deprecate(*method_names)
    ActiveSupport::Deprecation.deprecate_methods(self, *method_names)
  end
end
