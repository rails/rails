module ActionView
  module Helpers
    module Tags # :nodoc:
      class Base # :nodoc:
        include Helpers::ActiveModelInstanceTag, Helpers::TagHelper, Helpers::FormTagHelper
        include FormOptionsHelper

        attr_reader :object

        def initialize(object_name, method_name, template_object, options = {})
          @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
          @template_object = template_object

          @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
          @object = retrieve_object(options.delete(:object))
          @options = options
          @auto_index = Regexp.last_match ? retrieve_autoindex(Regexp.last_match.pre_match) : nil
        end

        # This is what child classes implement.
        def render
          raise NotImplementedError, "Subclasses must implement a render method"
        end

        private

          def value(object)
            object.public_send @method_name if object
          end

          def value_before_type_cast(object)
            unless object.nil?
              method_before_type_cast = @method_name + "_before_type_cast"

              if value_came_from_user?(object) && object.respond_to?(method_before_type_cast)
                object.public_send(method_before_type_cast)
              else
                value(object)
              end
            end
          end

          def value_came_from_user?(object)
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

          def add_default_name_and_id_for_value(tag_value, options)
            if tag_value.nil?
              add_default_name_and_id(options)
            else
              specified_id = options["id"]
              add_default_name_and_id(options)

              if specified_id.blank? && options["id"].present?
                options["id"] += "_#{sanitized_value(tag_value)}"
              end
            end
          end

          def add_default_name_and_id(options)
            index = name_and_id_index(options)
            options["name"] = options.fetch("name") { tag_name(options["multiple"], index) }
            options["id"] = options.fetch("id") { tag_id(index) }
            if namespace = options.delete("namespace")
              options["id"] = options["id"] ? "#{namespace}_#{options['id']}" : namespace
            end
          end

          def tag_name(multiple = false, index = nil)
            # a little duplication to construct less strings
            if index
              "#{@object_name}[#{index}][#{sanitized_method_name}]#{"[]" if multiple}"
            else
              "#{@object_name}[#{sanitized_method_name}]#{"[]" if multiple}"
            end
          end

          def tag_id(index = nil)
            # a little duplication to construct less strings
            if index
              "#{sanitized_object_name}_#{index}_#{sanitized_method_name}"
            else
              "#{sanitized_object_name}_#{sanitized_method_name}"
            end
          end

          def sanitized_object_name
            @sanitized_object_name ||= @object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
          end

          def sanitized_method_name
            @sanitized_method_name ||= @method_name.sub(/\?$/,"")
          end

          def sanitized_value(value)
            value.to_s.gsub(/\s/, "_").gsub(/[^-\w]/, "").downcase
          end

          def select_content_tag(option_tags, options, html_options)
            html_options = html_options.stringify_keys
            add_default_name_and_id(html_options)

            if placeholder_required?(html_options)
              raise ArgumentError, "include_blank cannot be false for a required field." if options[:include_blank] == false
              options[:include_blank] ||= true unless options[:prompt]
            end

            value = options.fetch(:selected) { value(object) }
            select = content_tag("select", add_options(option_tags, options, value), html_options)

            if html_options["multiple"] && options.fetch(:include_hidden, true)
              tag("input", disabled: html_options["disabled"], name: html_options["name"], type: "hidden", value: "") + select
            else
              select
            end
          end

          def placeholder_required?(html_options)
            # See https://html.spec.whatwg.org/multipage/forms.html#attr-select-required
            html_options["required"] && !html_options["multiple"] && html_options.fetch("size", 1).to_i == 1
          end

          def add_options(option_tags, options, value = nil)
            if options[:include_blank]
              option_tags = tag_builder.content_tag_string("option", options[:include_blank].kind_of?(String) ? options[:include_blank] : nil, value: "") + "\n" + option_tags
            end
            if value.blank? && options[:prompt]
              option_tags = tag_builder.content_tag_string("option", prompt_text(options[:prompt]), value: "") + "\n" + option_tags
            end
            option_tags
          end

          def name_and_id_index(options)
            options.key?("index") ?  options.delete("index") || "" : @auto_index
          end
      end
    end
  end
end
