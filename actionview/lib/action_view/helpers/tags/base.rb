module ActionView
  module Helpers
    module Tags # :nodoc:
      class Base # :nodoc:
        include Helpers::ActiveModelInstanceTag, Helpers::TagHelper, Helpers::FormTagHelper
        include FormOptionsHelper

        module Strings #:nodoc:
          BEFORE_TYPE_CAST = '_before_type_cast'.freeze
          BRACKET_LEFT = '['.freeze
          BRACKET_PAIR = '[]'.freeze
          BRACKET_RIGHT = ']'.freeze
          EMPTY = ''.freeze
          ID = 'id'.freeze
          INDEX = 'index'.freeze
          INPUT = 'input'.freeze
          DISABLED = 'disabled'.freeze
          HIDDEN = 'hidden'.freeze
          MULTIPLE = 'multiple'.freeze
          NAME = 'name'.freeze
          NAMESPACE = 'namespace'.freeze
          NEWLINE = "\n".freeze
          REQUIRED = 'required'.freeze
          SELECT = 'select'.freeze
          SIZE = 'size'.freeze
          UNDERSCORE = '_'.freeze
        end
        private_constant :Strings

        attr_reader :object

        def initialize(object_name, method_name, template_object, options = {})
          @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
          @template_object = template_object

          @object_name.sub!(/\[\]$/, Strings::EMPTY) || @object_name.sub!(/\[\]\]$/, Strings::BRACKET_RIGHT)
          @object_ivar = "@#{@object_name}".freeze
          @object = retrieve_object(options.delete(:object))
          @options = options
          @auto_index = retrieve_autoindex(Regexp.last_match.pre_match) if Regexp.last_match

          @method_before_type_cast = "#{@method_name}#{Strings::BEFORE_TYPE_CAST}".freeze
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
            object.respond_to?(@method_before_type_cast) ?
              object.send(@method_before_type_cast) :
              value(object)
          end
        end

        def retrieve_object(object)
          if object
            object
          elsif @template_object.instance_variable_defined?(@object_ivar)
            @template_object.instance_variable_get(@object_ivar)
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
            specified_id = options[Strings::ID]
            add_default_name_and_id(options)

            if specified_id.blank? && options[Strings::ID].present?
              options[Strings::ID] += "_#{sanitized_value(tag_value)}"
            end
          end
        end

        def add_default_name_and_id(options)
          if options.has_key?(Strings::INDEX)
            options[Strings::NAME] ||= options.fetch(Strings::NAME){ tag_name_with_index(options[Strings::INDEX], options[Strings::MULTIPLE]) }
            options[Strings::ID] = options.fetch(Strings::ID){ tag_id_with_index(options[Strings::INDEX]) }
            options.delete(Strings::INDEX)
          elsif defined?(@auto_index)
            options[Strings::NAME] ||= options.fetch(Strings::NAME){ tag_name_with_index(@auto_index, options[Strings::MULTIPLE]) }
            options[Strings::ID] = options.fetch(Strings::ID){ tag_id_with_index(@auto_index) }
          else
            options[Strings::NAME] ||= options.fetch(Strings::NAME){ tag_name(options[Strings::MULTIPLE]) }
            options[Strings::ID] = options.fetch(Strings::ID){ tag_id }
          end

          options[Strings::ID] = [options.delete(Strings::NAMESPACE), options[Strings::ID]].compact.join(Strings::UNDERSCORE).presence
        end

        def tag_name(multiple = false)
          "#{@object_name}[#{sanitized_method_name}]#{Strings::BRACKET_PAIR if multiple}"
        end

        def tag_name_with_index(index, multiple = false)
          "#{@object_name}[#{index}][#{sanitized_method_name}]#{Strings::BRACKET_PAIR if multiple}"
        end

        def tag_id
          "#{sanitized_object_name}_#{sanitized_method_name}"
        end

        def tag_id_with_index(index)
          "#{sanitized_object_name}_#{index}_#{sanitized_method_name}"
        end

        def sanitized_object_name
          @sanitized_object_name ||= @object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, Strings::UNDERSCORE).sub(/_$/, Strings::EMPTY)
        end

        def sanitized_method_name
          @sanitized_method_name ||= @method_name.sub(/\?$/, Strings::EMPTY)
        end

        def sanitized_value(value)
          value.to_s.gsub(/\s/, Strings::UNDERSCORE).gsub(/[^-\w]/, Strings::EMPTY).downcase
        end

        def select_content_tag(option_tags, options, html_options)
          html_options = html_options.stringify_keys
          add_default_name_and_id(html_options)
          options[:include_blank] ||= true unless options[:prompt] || select_not_required?(html_options)
          value = options.fetch(:selected) { value(object) }
          select = content_tag(Strings::SELECT, add_options(option_tags, options, value), html_options)

          if html_options[Strings::MULTIPLE] && options.fetch(:include_hidden, true)
            tag(Strings::INPUT, :disabled => html_options[Strings::DISABLED], :name => html_options[Strings::NAME], :type => Strings::HIDDEN, :value => Strings::EMPTY) + select
          else
            select
          end
        end

        def select_not_required?(html_options)
          !html_options[Strings::REQUIRED] || html_options[Strings::MULTIPLE] || html_options[Strings::SIZE].to_i > 1
        end

        def add_options(option_tags, options, value = nil)
          if options[:include_blank]
            option_tags = content_tag_string('option', options[:include_blank].kind_of?(String) ? options[:include_blank] : nil, :value => Strings::EMPTY) + Strings::NEWLINE + option_tags
          end
          if value.blank? && options[:prompt]
            option_tags = content_tag_string('option', prompt_text(options[:prompt]), :value => Strings::EMPTY) + Strings::NEWLINE + option_tags
          end
          option_tags
        end
      end
    end
  end
end
