module ActiveRecord
  module ValidationsRepairHelper
    extend ActiveSupport::Concern

    module ClassMethods
      def repair_validations(*model_classes)
        teardown do
          model_classes.each do |k|
            k.clear_validators!
          end
        end
      end
    end

    def repair_validations(*model_classes)
      yield if block_given?
    ensure
      model_classes.each do |k|
        k.clear_validators!
      end
    end
  end
end
