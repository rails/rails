# frozen_string_literal: true

module ActiveRecord
  class ReadonlyAttributeError < ActiveRecordError
  end

  module ReadonlyAttributes
    extend ActiveSupport::Concern

    included do
      class_attribute :_attr_readonly, instance_accessor: false, default: [].freeze
    end

    module ClassMethods
      # Attributes listed as readonly will be used to create a new record.
      # Assigning a new value to a readonly attribute on a persisted record raises an error.
      #
      # By setting +config.active_record.raise_on_assign_to_attr_readonly+ to +false+, it will
      # not raise. The value will change in memory, but will not be persisted on +save+.
      #
      # ==== Examples
      #
      #   class Post < ActiveRecord::Base
      #     attr_readonly :title
      #   end
      #
      #   post = Post.create!(title: "Introducing Ruby on Rails!")
      #   post.title = "a different title" # raises ActiveRecord::ReadonlyAttributeError
      #   post.update(title: "a different title") # raises ActiveRecord::ReadonlyAttributeError
      def attr_readonly(*attributes)
        self._attr_readonly = ActiveSupport::Ractors.make_shareable(_attr_readonly | attributes.map(&:to_s))

        if ActiveRecord._raise_on_assign_to_attr_readonly
          undefine_attribute_methods # The code generator changed
          include(HasReadonlyAttributes)
        end
      end

      # Returns an array of all the attributes that have been specified as readonly.
      def readonly_attributes
        _attr_readonly
      end

      def readonly_attribute?(name) # :nodoc:
        _attr_readonly.include?(name)
      end

      private
        def define_method_attribute=(canonical_name, owner:, as: canonical_name)
          if ActiveRecord._raise_on_assign_to_attr_readonly && readonly_attribute?(canonical_name)
            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              canonical_name, writer: true,
            ) do |temp_method_name, attr_name_expr|
              owner.define_cached_method(temp_method_name, as: "#{as}=", namespace: :active_record_readonly) do |batch|
                batch <<
                  "def #{temp_method_name}(value)" <<
                  "  unless new_record?" <<
                  "    raise ActiveRecord::ReadonlyAttributeError.new(#{attr_name_expr})" <<
                  "  end" <<
                  "  @attributes.write_from_user(#{attr_name_expr}, value)" <<
                  "end"
              end
            end
          else
            super
          end
        end
    end

    module HasReadonlyAttributes # :nodoc:
      def write_attribute(attr_name, value)
        if !new_record? && self.class.readonly_attribute?(attr_name.to_s)
          raise ReadonlyAttributeError.new(attr_name)
        end

        super
      end

      def _write_attribute(attr_name, value)
        if !new_record? && self.class.readonly_attribute?(attr_name.to_s)
          raise ReadonlyAttributeError.new(attr_name)
        end

        super
      end
    end
  end
end
