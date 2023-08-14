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

        # Given an attribute and a pattern, identify any manually defined methods in the
        # aliased chain.
        # Returns the far attribute, target definition name, the already defined method (if it exists) and a boolean of whether all targets are attribute methods.
        def find_attribute_targets(old_name, pattern)
          all_targets_are_attribute_methods = true

          far_name = next_name = old_name
          while next_name
            far_name = next_name

            far_target = pattern.method_name(far_name).to_s
            far_method = (instance_method(far_target) if method_defined?(far_target) || private_method_defined?(far_target))
            if far_method
              unless far_method.owner == generated_attribute_methods || far_method.owner == ActiveRecord::AttributeMethods::PrimaryKey
                all_targets_are_attribute_methods = false
                break
              end
            elsif attribute_aliases.key?(far_name)
              # walk past a missing method in the alias chain: it might not be defined yet
            else
              all_targets_are_attribute_methods = false
              break
            end

            next_name = attribute_aliases[far_name]
          end

          [all_targets_are_attribute_methods, far_name, far_method, far_target]
        end

        def add_alias_attribute_deprecation_warning(far_name, far_method, far_target, new_name, old_name, method_name)
          # TODO: We should warn about this too. Either it's a typo, or
          # it indicates a possible backwards compatibility issue we
          # haven't directly addressed, like a target that's being provided
          # by method_missing.
          return unless far_method

          alias_chain = far_name == old_name ? "" : ", which in turn aliases to `#{far_name}`"
          intro = "#{self} uses `alias_attribute :#{new_name}, :#{old_name}`#{alias_chain}"

          # It's an attribute, this is just an overridden method
          if has_attribute?(far_name)
            where = far_method.owner == self ? "" : " in #{far_method.owner}"

            ActiveRecord.deprecator.warn(
              "#{intro}, and also overrides the `#{far_target}` method#{where}. " \
              "In Rails 7.2, `#{method_name}` will directly access the `#{far_name}` attribute value instead of calling the method; " \
              "explicitly forward or alias `#{method_name}` to `#{far_target}` to preserve the current behavior."
            )

          # Common anti-pattern: using alias_attribute to alias an association
          elsif reflect_on_association(far_name)
            ActiveRecord.deprecator.warn(
              "#{intro}, but `#{far_name}` is an association. " \
              "In Rails 7.2, alias_attribute will no longer work with associations; " \
              "use `alias_association :#{new_name}, :#{far_name}` instead."
            )

          # Also anti-pattern: using alias_attribute to alias a plain method
          else
            ActiveRecord.deprecator.warn(
              "#{intro}, but `#{far_name}` is not an attribute. " \
              "In Rails 7.2, alias_attribute will no longer work with non-attributes; " \
              "define `#{method_name}` or use `alias_method :#{method_name}, :#{far_target}` instead."
            )
          end
        end
       
      end  
    end
  end
end
