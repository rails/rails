module ActiveRecord
  module Testing
    module RepairHelper
      extend ActiveSupport::Concern

      module Toolbox
        def self.record_validations(*model_classes)
          model_classes.inject({}) do |repair, klass|
            repair[klass] ||= {}
            [:validate, :validate_on_create, :validate_on_update].each do |callback|
              the_callback = klass.instance_variable_get("@#{callback.to_s}_callbacks")
              repair[klass][callback] = (the_callback.nil? ? nil : the_callback.dup)
            end
            repair
          end
        end

        def self.reset_validations(recorded)
          recorded.each do |klass, repairs|
            [:validate, :validate_on_create, :validate_on_update].each do |callback|
              klass.instance_variable_set("@#{callback.to_s}_callbacks", repairs[callback])
            end
          end
        end
      end

      module ClassMethods
        def repair_validations(*model_classes)
          setup do
            @validation_repairs = ActiveRecord::Testing::RepairHelper::Toolbox.record_validations(*model_classes)
          end
          teardown do
            ActiveRecord::Testing::RepairHelper::Toolbox.reset_validations(@validation_repairs)
          end
        end
      end

      def repair_validations(*model_classes, &block)
        validation_repairs = ActiveRecord::Testing::RepairHelper::Toolbox.record_validations(*model_classes)
        return block.call
      ensure
        ActiveRecord::Testing::RepairHelper::Toolbox.reset_validations(validation_repairs)
      end
    end
  end
end
