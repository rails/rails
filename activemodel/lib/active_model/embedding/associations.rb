# frozen_string_literal: true

module ActiveModel
  module Embedding
    module Associations
      def self.included(klass)
        klass.class_eval do
          extend ClassMethods

          class_variable_set :@@embedded_associations, []

          around_save :save_embedded_documents

          def save_embedded_documents
            klass = self.class

            if klass.embedded_associations.present?
              associations = klass.embedded_associations

              targets = associations.filter_map do |association_name|
                public_send association_name
              end

              targets.each(&:save)
            end

            yield
          end
        end
      end

      module ClassMethods
        def embeds_many(attr_name, class_name: nil, cast_type: nil, collection: nil)
          class_name = cast_type ? nil : class_name || infer_class_name_from(attr_name)

          attribute :"#{attr_name}", :document,
            class_name: class_name,
            cast_type: cast_type,
            collection: collection || true,
            context: self.to_s

          register_embedded_association attr_name

          nested_attributes_for attr_name
        end

        def embeds_one(attr_name, class_name: nil, cast_type: nil)
          class_name = cast_type ? nil : class_name || infer_class_name_from(attr_name)

          attribute :"#{attr_name}", :document,
            class_name: class_name,
            cast_type: cast_type,
            context: self.to_s

          register_embedded_association attr_name

          nested_attributes_for attr_name
        end

        def embedded_associations
          class_variable_get :@@embedded_associations
        end

        private
          def infer_class_name_from(attr_name)
            attr_name.to_s.singularize.camelize
          end

          def register_embedded_association(name)
            embedded_associations << name
          end

          def nested_attributes_for(attr_name)
            delegate :attributes=, to: :"#{attr_name}", prefix: true
          end
      end
    end
  end
end
