module ActionView
  module Helpers
    module Tags
      class Base #:nodoc:
        include Helpers::ActiveModelInstanceTag, Helpers::TagHelper, Helpers::FormTagHelper
        include FormOptionsHelper

        DEFAULT_FIELD_OPTIONS = { "size" => 30 }

        attr_reader :object

        def initialize(object_name, method_name, template_object, options = {})
          @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
          @template_object = template_object

          @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
          @object = retrieve_object(options.delete(:object))
          @options = options
          @auto_index = retrieve_autoindex(Regexp.last_match.pre_match) if Regexp.last_match
        end

        # This is what child classes implement.
        def render
          raise NotImplementedError, "Subclasses must implement a render method"
        end

        private

        def value(object)
          object.send @method_name if object
        end

        def value_before_type_cast(object)
          unless object.nil?
            object.respond_to?(@method_name + "_before_type_cast") ?
            object.send(@method_name + "_before_type_cast") :
            object.send(@method_name)
          end
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

        def select_content_tag(option_tags, options, html_options)
          html_options = html_options.stringify_keys
          add_default_name_and_id(html_options)
          select = content_tag("select", add_options(option_tags, options, value(object)), html_options)
          if html_options["multiple"]
            tag("input", :disabled => html_options["disabled"], :name => html_options["name"], :type => "hidden", :value => "") + select
          else
            select
          end
        end

        def add_options(option_tags, options, value = nil)
          if options[:include_blank]
            option_tags = "<option value=\"\">#{ERB::Util.html_escape(options[:include_blank]) if options[:include_blank].kind_of?(String)}</option>\n" + option_tags
          end
          if value.blank? && options[:prompt]
            prompt = options[:prompt].kind_of?(String) ? options[:prompt] : I18n.translate('helpers.select.prompt', :default => 'Please select')
            option_tags = "<option value=\"\">#{ERB::Util.html_escape(prompt)}</option>\n" + option_tags
          end
          option_tags.html_safe
        end
      end
    end
  end
end
