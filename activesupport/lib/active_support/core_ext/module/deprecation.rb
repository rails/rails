require 'active_support/deprecation/method_wrappers'

class Module
  #   deprecate :foo
  #   deprecate :bar => 'message'
  #   deprecate :foo, :bar, :baz => 'warning!', :qux => 'gone!'
  #
  # You can use custom deprecator instance
  #   deprecate :foo, :deprecator => MyLib::Deprecator.new
  #   deprecate :foo, :bar => "warning!", :deprecator => MyLib::Deprecator.new
  #
  # \Custom deprecators must respond to one method
  # [deprecation_warning(deprecated_method_name, message, caller_backtrace)] will be called with the deprecated
  #                                                                          method name, the message it was declared
  #                                                                          with and caller_backtrace. Implement
  #                                                                          whatever warning behavior you like here.
  #
  # Example
  #    class MyLib::Deprecator
  #
  #      def deprecation_warning(deprecated_method_name, message, caller_backtrace)
  #         message = "#{method_name} is deprecated and will be removed from MyLibrary | #{message}"
  #         Kernel.warn message
  #      end
  #
  #    end
  #
  #    module MyLib
  #      mattr_accessor :deprecator
  #      self.deprecator = Deprecator.new
  #    end
  #
  # When we deprecate method
  #    class MyLib::Bar
  #      deprecate :foo => "this is very old method", :deprecator => MyLib.deprecator
  #    end
  #
  # It will build deprecation message and invoke deprecator warning by calling
  #   MyLib.deprecator.deprecation_warning(:foo, "this is a very old method", caller)
  def deprecate(*method_names)
    ActiveSupport::Deprecation.deprecate_methods(self, *method_names)
  end
end
