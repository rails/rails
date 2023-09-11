# frozen_string_literal: true

module ActiveModel
  module Validations
    # = Active \Model \Validation \Callbacks
    #
    # Provides an interface for any class to have ClassMethods#before_validation and
    # ClassMethods#after_validation callbacks.
    #
    # First, include +ActiveModel::Validations::Callbacks+ from the class you are
    # creating:
    #
    #   class MyModel
    #     include ActiveModel::Validations::Callbacks
    #
    #     before_validation :do_stuff_before_validation
    #     after_validation  :do_stuff_after_validation
    #   end
    #
    # Like other <tt>before_*</tt> callbacks if +before_validation+ throws
    # +:abort+ then <tt>valid?</tt> will not be called.
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :validation,
                         skip_after_callbacks_if_terminated: true,
                         scope: [:kind, :name]
      end

      module ClassMethods
        # Defines a callback that will get called right before validation.
        #
        #   class Person
        #     include ActiveModel::Validations
        #     include ActiveModel::Validations::Callbacks
        #
        #     attr_accessor :name
        #
        #     validates_length_of :name, maximum: 6
        #
        #     before_validation :remove_whitespaces
        #
        #     private
        #       def remove_whitespaces
        #         name.strip!
        #       end
        #   end
        #
        #   person = Person.new
        #   person.name = '  bob  '
        #   person.valid? # => true
        #   person.name   # => "bob"
        def before_validation(*args, &block)
          options = args.extract_options!

          set_options_for_callback(options)

          set_callback(:validation, :before, *args, options, &block)
        end

        # Defines a callback that will get called right after validation.
        #
        #   class Person
        #     include ActiveModel::Validations
        #     include ActiveModel::Validations::Callbacks
        #
        #     attr_accessor :name, :status
        #
        #     validates_presence_of :name
        #
        #     after_validation :set_status
        #
        #     private
        #       def set_status
        #         self.status = errors.empty?
        #       end
        #   end
        #
        #   person = Person.new
        #   person.name = ''
        #   person.valid? # => false
        #   person.status # => false
        #   person.name = 'bob'
        #   person.valid? # => true
        #   person.status # => true
        def after_validation(*args, &block)
          options = args.extract_options!
          options = options.dup
          options[:prepend] = true

          set_options_for_callback(options)

          set_callback(:validation, :after, *args, options, &block)
        end

        private
          def set_options_for_callback(options)
            if options.key?(:on)
              options[:on] = Array(options[:on])
              options[:if] = [
                ->(o) {
                  !(options[:on] & Array(o.validation_context)).empty?
                },
                *options[:if]
              ]
            end
          end
      end

    private
      # Override run_validations! to include callbacks.
      def run_validations!
        _run_validation_callbacks { super }
      end
    end
  end
end
