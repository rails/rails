module ActiveModel
  module Validations
    VALIDATIONS = %w( validate validate_on_create validate_on_update )

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send!(:include, ActiveSupport::Callbacks)

      VALIDATIONS.each do |validation_method|
        base.class_eval <<-"end_eval"
          def self.#{validation_method}(*methods, &block)
            methods = CallbackChain.build(:#{validation_method}, *methods, &block)
            self.#{validation_method}_callback_chain.replace(#{validation_method}_callback_chain | methods)
          end

          def self.#{validation_method}_callback_chain
            if chain = read_inheritable_attribute(:#{validation_method})
              return chain
            else
              write_inheritable_attribute(:#{validation_method}, CallbackChain.new)
              return #{validation_method}_callback_chain
            end
          end
        end_eval
      end
    end

    # All of the following validations are defined in the class scope of the model that you're interested in validating.
    # They offer a more declarative way of specifying when the model is valid and when it is not. It is recommended to use
    # these over the low-level calls to validate and validate_on_create when possible.
    module ClassMethods
      DEFAULT_VALIDATION_OPTIONS = {
        :on          => :save,
        :allow_nil   => false,
        :allow_blank => false,
        :message     => nil
      }.freeze

      private
        def validation_method(on)
          case on
            when :save   then :validate
            when :create then :validate_on_create
            when :update then :validate_on_update
          end
        end
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new
    end

    # Runs all the specified validations and returns true if no errors were added otherwise false.
    def valid?
      errors.clear

      run_callbacks(:validate)
      
      if responds_to?(:validate)
        ActiveSupport::Deprecations.warn "Base#validate has been deprecated, please use Base.validate :method instead"
        validate
      end

      if new_record?
        run_callbacks(:validate_on_create)

        if responds_to?(:validate_on_create)
          ActiveSupport::Deprecations.warn(
            "Base#validate_on_create has been deprecated, please use Base.validate :method, :on => :create instead")
          validate_on_create
        end
      else
        run_callbacks(:validate_on_update)

        if responds_to?(:validate_on_update)
          ActiveSupport::Deprecations.warn(
            "Base#validate_on_update has been deprecated, please use Base.validate :method, :on => :update instead")
          validate_on_update
        end
      end

      errors.empty?
    end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/validations/#{filename}"
end