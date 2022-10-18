# frozen_string_literal: true

module ActiveModel
  module Embedding
    module Document
      def self.included(klass)
        klass.class_eval do
          extend ClassMethods
          extend ActiveModel::Callbacks

          define_model_callbacks :save

          include ActiveModel::Model
          include ActiveModel::Attributes
          include ActiveModel::Serializers::JSON
          include Embedding::Associations

          attribute :id, :integer

          def save
            run_callbacks :save do
              return false unless valid?

              self.id = object_id unless persisted?

              true
            end
          end

          def persisted?
            id.present?
          end

          def ==(other)
            attributes == other.attributes
          end
        end
      end

      module ClassMethods
        def validates_associated(*attr_names)
          validates_with ActiveRecord::Validations::AssociatedValidator,
            _merge_attributes(attr_names)
        end
      end
    end
  end
end
