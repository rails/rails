# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class Base # :nodoc:
        include Helpers::ActiveModelInstanceTag, Helpers::TagHelper, Helpers::FormTagHelper

        attr_reader :object

        def initialize(object_name, method_name, template_object, options = {})
          @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
          @template_object = template_object

          @object_name.sub!(/\[\]$/, "") || @object_name.sub!(/\[\]\]$/, "]")
          @object = retrieve_object(options.delete(:object))
          @skip_default_ids = options.delete(:skip_default_ids)
          @allow_method_names_outside_object = options.delete(:allow_method_names_outside_object)
          @options = options

          if Regexp.last_match
            @generate_indexed_names = true
            @auto_index = retrieve_autoindex(Regexp.last_match.pre_match)
          else
            @generate_indexed_names = false
            @auto_index = nil
          end
        end

        # This is what child classes implement.
        def render
          raise NotImplementedError, "Subclasses must implement a render method"
        end

        private
          def value
            return unless object

            if @allow_method_names_outside_object
              object.public_send @method_name if object.respond_to?(@method_name)
            else
              object.public_send @method_name
            end
          end

          def value_before_type_cast
            return unless object

            method_before_type_cast = @method_name + "_before_type_cast"

            if value_came_from_user? && object.respond_to?(method_before_type_cast)
              object.public_send(method_before_type_cast)
            else
              value
            end
          end

          def value_came_from_user?
            method_name = "#{@method_name}_came_from_user?"
            !object.respond_to?(method_name) || object.public_send(method_name)
          end

          def retrieve_object(object)
            if object
              object
            elsif @template_object.instance_variable_defined?("@#{@object_name}")
              @template_object.instance_variable_get("@#{@object_name}")
            end
          rescue NameError
            # As @object_name may contain the nested syntax (item[subobject]) we need to fallback to nil.
            nil
          end

          def retrieve_autoindex(pre_match)
            object = self.object || @template_object.instance_variable_get("@#{pre_match}")
            if object && object.respond_to?(:to_param)
              object.to_param
            else
              raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
            end
          end

          def add_default_name_and_field_for_value(tag_value, options, field = "id")
            if tag_value.nil?
              add_default_name_and_field(options, field)
            else
              specified_field = options[field]
              add_default_name_and_field(options, field)

              if specified_field.blank? && options[field].present?
                options[field] += "_#{sanitized_value(tag_value)}"
              end
            end
          end

          def add_default_name_and_field(options, field = "id")
            index = name_and_id_index(options)
            options["name"] = options.fetch("name") { tag_name(options["multiple"], index) }

            if generate_ids?
              options[field] = options.fetch(field) { tag_id(index, options.delete("namespace")) }
              if namespace = options.delete("namespace")
                options[field] = options[field] ? "#{namespace}_#{options[field]}" : namespace
              end
            end
          end

          def tag_name(multiple = false, index = nil)
            @template_object.field_name(@object_name, sanitized_method_name, multiple: multiple, index: index)
          end

          def tag_id(index = nil, namespace = nil)
            @template_object.field_id(@object_name, @method_name, index: index, namespace: namespace)
          end

          def sanitized_method_name
            @sanitized_method_name ||= @method_name.delete_suffix("?")
          end

          def sanitized_value(value)
            value.to_s.gsub(/[\s.]/, "_").gsub(/[^-[[:word:]]]/, "").downcase
          end

          def name_and_id_index(options)
            if options.key?("index")
              options.delete("index") || ""
            elsif @generate_indexed_names
              @auto_index || ""
            end
          end

          def generate_ids?
            !@skip_default_ids
          end
      end
    end
  end
end
