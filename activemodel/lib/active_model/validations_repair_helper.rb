module ActiveModel
  module ValidationsRepairHelper
    extend ActiveSupport::Concern

    module ClassMethods
      def repair_validations(*model_classes)
        setup do
          @_stored_callbacks = {}
          model_classes.each do |k|
            @_stored_callbacks[k] = k._validate_callbacks.dup
          end
        end
        teardown do
          model_classes.each do |k|
            k._validate_callbacks = @_stored_callbacks[k]
            k.__update_callbacks(:validate)
          end
        end
      end
    end

    def repair_validations(*model_classes, &block)
      @__stored_callbacks = {}
      model_classes.each do |k|
        @__stored_callbacks[k] = k._validate_callbacks.dup
      end
      return block.call
    ensure
      model_classes.each do |k|
        k._validate_callbacks = @__stored_callbacks[k]
        k.__update_callbacks(:validate)
      end
    end
  end
end
