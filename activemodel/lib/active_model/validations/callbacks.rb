require 'active_support/callbacks'

module ActiveModel
  module Validations
    module Callbacks
      # == Active Model Validation callbacks
      #
      # Provides an interface for any class to have <tt>before_validation</tt> and
      # <tt>after_validation</tt> callbacks.
      #
      # First, extend ActiveModel::Callbacks from the class you are creating:
      #
      #   class MyModel
      #     include ActiveModel::Validations::Callbacks
      #
      #     before_validation :do_stuff_before_validation
      #     after_validation  :do_tuff_after_validation
      #   end
      #
      #   Like other before_* callbacks if <tt>before_validation</tt> returns false
      #   then <tt>valid?</tt> will not be called.
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :validation, :terminator => "result == false", :scope => [:kind, :name]
      end

      module ClassMethods
        def before_validation(*args, &block)
          options = args.last
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array.wrap(options[:if])
            options[:if] << "self.validation_context == :#{options[:on]}"
          end
          set_callback(:validation, :before, *args, &block)
        end

        def after_validation(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array.wrap(options[:if])
          options[:if] << "!halted && value != false"
          options[:if] << "self.validation_context == :#{options[:on]}" if options[:on]
          set_callback(:validation, :after, *(args << options), &block)
        end
      end

      # Runs all the specified validations and returns true if no errors were added
      # otherwise false. Context can optionally be supplied to define which callbacks
      # to test against (the context is defined on the validations using :on).
      def valid?(context = nil)
        current_context, self.validation_context = validation_context, context
        errors.clear
        @validate_callback_result = nil
        validation_callback_result = _run_validation_callbacks { @validate_callback_result = _run_validate_callbacks }
        (validation_callback_result && @validate_callback_result) ? errors.empty? : false
      ensure
        self.validation_context = current_context
      end

    end
  end
end
