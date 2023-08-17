# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods \Validation
    module Validation
      extend ActiveSupport::Concern

      module ClassMethods
        def aliased_method_redefined?(method_name)
          method_defined_within?(method_name, self)
        end

        def check_for_deprecations(target_method, target_association_name)
          # TODO: We should warn about this too. Either it's a typo, or
          # it indicates a possible backwards compatibility issue we
          # haven't directly addressed, like a target that's being provided
          # by method_missing
          return unless target_method
          is_attribute_method = target_method.owner == generated_attribute_methods || target_method.owner == ActiveRecord::AttributeMethods::PrimaryKey

          # It's an attribute, this is just an overridden method
          if has_attribute?(target_association_name) && !is_attribute_method
            return :missing_forward_for_manually_defined_method
          end

          # Common anti-pattern: using alias_attribute to alias an association
          if reflect_on_association(target_association_name)
            return :target_is_association
          end

          # Also anti-pattern: using alias_attribute to alias a plain method
          if !has_attribute?(target_association_name)
            :not_an_attribute
          end
        end

        def add_alias_attribute_deprecation_warning(new_name, old_name, method_name, target_method_name, target_method, far_name, deprecation_type)
          return unless deprecation_type
          alias_chain = far_name == old_name ? "" : ", which in turn aliases to `#{far_name}`"
          intro = "#{self} uses `alias_attribute :#{new_name}, :#{old_name}`#{alias_chain}"

          case deprecation_type
          when :missing_forward_for_manually_defined_method
            where = target_method.owner == self ? "" : " in #{target_method.owner}"

            ActiveRecord.deprecator.warn(
              "#{intro}, and also overrides the `#{target_method_name}` method#{where}. " \
              "In Rails 7.2, `#{method_name}` will directly access the `#{old_name}` attribute value instead of calling the method; " \
              "explicitly forward or alias `#{method_name}` to `#{target_method_name}` to preserve the current behavior."
            )
          when :target_is_association
            ActiveRecord.deprecator.warn(
              "#{intro}, but `#{far_name}` is an association. " \
              "In Rails 7.2, alias_attribute will no longer work with associations; " \
              "use `alias_association :#{new_name}, :#{far_name}` instead."
            )
          when :not_an_attribute
            ActiveRecord.deprecator.warn(
              "#{intro}, but `#{far_name}` is not an attribute. " \
              "In Rails 7.2, alias_attribute will no longer work with non-attributes; " \
              "define `#{method_name}` or use `alias_method :#{method_name}, :#{old_name}` instead."
            )
          end
        end

        def find_attribute_far_name(old_name)
          far_name = next_name = old_name
          while next_name
            next_name = attribute_aliases[next_name]
            far_name = next_name if next_name
          end
          far_name
        end
      end
    end
  end
end
