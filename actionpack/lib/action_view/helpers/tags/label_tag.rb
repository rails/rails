module ActionView
  module Helpers
    module Tags
      class LabelTag
        include Helpers::TagHelper, Helpers::FormTagHelper

        attr_reader :object

        def initialize(object_name, method_name, template_object, content, options)
          content_is_options = content.is_a?(Hash)
          if content_is_options
            options = content
            @content = nil
          else
            @content = content
          end

          options ||= {}

          @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
          @template_object = template_object

          @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
          @object = retrieve_object(options.delete(:object))
          @options = options
          @auto_index = retrieve_autoindex(Regexp.last_match.pre_match) if Regexp.last_match
        end

        def render(&block)
          options = @options.stringify_keys
          tag_value = options.delete("value")
          name_and_id = options.dup

          if name_and_id["for"]
            name_and_id["id"] = name_and_id["for"]
          else
            name_and_id.delete("id")
          end

          add_default_name_and_id_for_value(tag_value, name_and_id)
          options.delete("index")
          options.delete("namespace")
          options["for"] ||= name_and_id["id"]

          if block_given?
            @template_object.label_tag(name_and_id["id"], options, &block)
          else
            content = if @content.blank?
                        @object_name.gsub!(/\[(.*)_attributes\]\[\d\]/, '.\1')
                        method_and_value = tag_value.present? ? "#{@method_name}.#{tag_value}" : @method_name

                        if object.respond_to?(:to_model)
                          key = object.class.model_name.i18n_key
                          i18n_default = ["#{key}.#{method_and_value}".to_sym, ""]
                        end

                        i18n_default ||= ""
                        I18n.t("#{@object_name}.#{method_and_value}", :default => i18n_default, :scope => "helpers.label").presence
                      else
                        @content.to_s
                      end

            content ||= if object && object.class.respond_to?(:human_attribute_name)
                          object.class.human_attribute_name(@method_name)
                        end

            content ||= @method_name.humanize

            label_tag(name_and_id["id"], content, options)
          end
        end

        private

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
          unless tag_value.nil?
            pretty_tag_value = tag_value.to_s.gsub(/\s/, "_").gsub(/[^-\w]/, "").downcase
            specified_id = options["id"]
            add_default_name_and_id(options)
            options["id"] += "_#{pretty_tag_value}" if specified_id.blank? && options["id"].present?
          else
            add_default_name_and_id(options)
          end
        end

        def add_default_name_and_id(options)
          if options.has_key?("index")
            options["name"] ||= tag_name_with_index(options["index"])
            options["id"] = options.fetch("id"){ tag_id_with_index(options["index"]) }
            options.delete("index")
          elsif defined?(@auto_index)
            options["name"] ||= tag_name_with_index(@auto_index)
            options["id"] = options.fetch("id"){ tag_id_with_index(@auto_index) }
          else
            options["name"] ||= tag_name + (options['multiple'] ? '[]' : '')
            options["id"] = options.fetch("id"){ tag_id }
          end
          options["id"] = [options.delete('namespace'), options["id"]].compact.join("_").presence
        end

        def tag_name
          "#{@object_name}[#{sanitized_method_name}]"
        end

        def tag_name_with_index(index)
          "#{@object_name}[#{index}][#{sanitized_method_name}]"
        end

        def tag_id
          "#{sanitized_object_name}_#{sanitized_method_name}"
        end

        def tag_id_with_index(index)
          "#{sanitized_object_name}_#{index}_#{sanitized_method_name}"
        end

        def sanitized_object_name
          @sanitized_object_name ||= @object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
        end

        def sanitized_method_name
          @sanitized_method_name ||= @method_name.sub(/\?$/,"")
        end
      end
    end
  end
end
