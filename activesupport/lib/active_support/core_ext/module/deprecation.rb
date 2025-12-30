# frozen_string_literal: true

class Module
  #   deprecate :foo, deprecator: MyLib.deprecator
  #   deprecate :foo, bar: "warning!", deprecator: MyLib.deprecator
  #
  # A deprecator is typically an instance of ActiveSupport::Deprecation, but you can also pass any object that responds
  # to <tt>deprecation_warning(deprecated_method_name, message, caller_backtrace)</tt> where you can implement your
  # custom warning behavior.
  #
  #   class MyLib::Deprecator
  #     def deprecation_warning(deprecated_method_name, message, caller_backtrace = nil)
  #       message = "#{deprecated_method_name} is deprecated and will be removed from MyLibrary | #{message}"
  #       Kernel.warn message
  #     end
  #   end
  def deprecate(*method_names, deprecator:, **options)
    if deprecator.is_a?(ActiveSupport::Deprecation)
      deprecator.deprecate_methods(self, *method_names, **options)
    elsif deprecator
      # we just need any instance to call deprecate_methods, but the deprecation will be emitted by deprecator
      ActiveSupport.deprecator.deprecate_methods(self, *method_names, **options, deprecator: deprecator)
    end
  end
end
