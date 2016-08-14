require "action_view/model_naming"

module ActionView
  module Helpers
    module FormWithHelper
      class FormWithBuilder
        include ActionView::Helpers::TagHelper
        include ModelNaming

        INPUT_FIELD_HELPERS = [:hidden_field, :text_field, :password_field, :color_field,
                        :search_field, :telephone_field, :phone_field, :date_field, :time_field,
                        :datetime_field, :datetime_local_field, :month_field, :week_field,
                        :url_field, :email_field, :number_field, :range_field]

        attr_accessor :model, :scope

        INPUT_FIELD_HELPERS.each do |selector|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{selector}(attribute, value = nil, **options)                                         # def text_field(attribute, value = nil, **options)
              tag.input field_options('#{selector.to_s.split("_").first}', attribute, value, options)  # tag.input field_options('text', attribute, args, options)
            end                                                                                        # end
          RUBY_EVAL
        end

        def file_field(attribute, **options)
          multiple = options.slice(:multiple)
          options = default_options(attribute, options)
          options[:type] = "file"
          options.merge!(multiple)
          tag.input options
        end

        def submit
          tag.input value: submit_default_value, "data-disable-with": submit_default_value, type: "submit", name: "commit"
        end

        def text_area(attribute, content = nil, placeholder: nil, **options)
          options = default_options(attribute, options)
          options[:placeholder] = placeholder(placeholder, attribute)
          if options.key?(:content)
            content = options.delete(:content)
          elsif model
            content ||= model.send(attribute)
          end
          tag.textarea(content, options)
        end

        def label(attribute, content = nil, **options, &block)
          content = @template.capture(content, &block) if block_given?
          content ||= I18n.t("#{model.model_name.i18n_key}.#{attribute}", default: "", scope: "helpers.label").presence if model && model.model_name
          content ||= translate_with_human_attribute_name(attribute)
          content ||= attribute.to_s.humanize
          tag.label content, options
        end

        def check_box(attribute, include_hidden: true, on: "1", off: "0", **options)
          options = default_options(attribute, options)
          checkbox_options = options.merge(type: "checkbox", value: on)
          checkbox_options[:checked] = "checked" if model && checked?(on, model.send(attribute))
          include_hidden = false if off.nil?
          if include_hidden
            hidden_options = options.merge(type: "hidden", value: off)
            hidden_options.delete(:checked)
            hidden = tag.input(hidden_options).html_safe
            hidden + tag.input(checkbox_options).html_safe
          else
            tag.input(checkbox_options).html_safe
          end
        end

        def radio_button(attribute, value = nil, **options)
          options = default_options(attribute, options)
          unless value.nil?
            options[:value] = value.to_s
            options[:checked] = "checked" if model.public_send(attribute).to_s == value
          end
          options[:type] = "radio"
          tag.input(options).html_safe
        end

        def select(attribute, choices = nil, value: :value, text: :text, collection: nil, blank: nil, prompt: nil, index: :undefined, disabled: nil, **options, &block)
          if collection
            choices = collection.map { |object| [object.send(value), object.send(text)] }
          end
          tag.select option_tags_for_select(choices, blank: blank), default_options(attribute, options)
        end

        def option_tags_for_select(choices, blank: false)
          built_options = choices.map do |(title, value)|
            tag.option title, value: value || title
          end.join("\n")

          if blank
            tag.option("", value: "").html_safe + built_options.html_safe
          else
            built_options.html_safe
          end
        end

        def fields(model: nil, indexed: false, index: nil, as: nil, &block)
          model_name = model_name_from_record_or_class(model).param_key
          indexing = "[#{index}]" if index
          indexing ||= "[#{model.to_param}]" if indexed
          naming = "[#{as ? as : model_name}]"
          inner_scope = "#{self.scope}#{naming}#{indexing}"
          new_builder = FormWithBuilder.new(@template, model, inner_scope)
          @template.capture(new_builder, &block)
        end

        private
          def checked?(on_value, value)
            case value
            when TrueClass, FalseClass
              value == !!on_value
            when NilClass
              false
            when String
              value == on_value
            else
              if value.respond_to?(:include?)
                value.include?(on_value)
              else
                value.to_i == on_value.to_i
              end
            end
          end

          def translate_with_human_attribute_name(attribute)
            if model && model.class.respond_to?(:human_attribute_name)
              model.class.human_attribute_name(attribute)
            end
          end

          def submit_default_value
            if scope
              key = model ? (model.persisted? ? :update : :create) : :submit
              model_name = model.respond_to?(:model_name) ? model.model_name.human : scope.to_s.humanize
              defaults = [:"helpers.submit.#{scope}.#{key}", :"helpers.submit.#{key}", :"#{key.to_s.humanize} #{model_name}"]
              I18n.t(defaults.shift, model: model_name, default: defaults)
            else
              I18n.t("helpers.submit.no_model")
            end
          end

          def input_name(attribute, index: nil, multiple: nil, **options)
            attribute = attribute.to_s.chomp("?")
            indexing   = "[#{index}]" if index
            multipling = "[]" if multiple
            scope = options.delete(:scope) { @scope }
            if scope
              "#{scope}#{indexing}[#{attribute}]#{multipling}"
            else
              "#{attribute}#{indexing}#{multipling}"
            end
          end

          def default_options(attribute, options)
            unless options.key?(:name)
              options[:name] ||= input_name(attribute, options)
            end
            options.delete(:multiple)
            options.delete(:index)
            options.delete(:scope)
            options
          end

          def field_options(field_type, attribute, value = nil, placeholder: nil, **options)
            options = default_options(attribute, options)

            if options.key?(:value)
            elsif value
              options[:value] = value
            elsif @model && !field_type.match("password")
              options[:value] ||= @model.public_send(attribute)
            end

            options[:placeholder] = placeholder(placeholder, attribute)
            options[:size] = options[:maxlength] unless options.key?(:size)
            options[:type] ||= field_type
            options
          end

          def placeholder(tag_value, attribute)
            if tag_value
              placeholder = tag_value if tag_value.is_a?(String)
              attribute_and_value = tag_value.is_a?(TrueClass) ? attribute : "#{attribute}.#{tag_value}"
              placeholder ||= Tags::Translator.new(model, scope, attribute_and_value, scope: "helpers.placeholder").translate
              placeholder ||= attribute.to_s.humanize
            end
          end

          def initialize(template, model, scope)
            @template = template
            @model = model
            @scope = scope
          end
      end

      def form_with(model: nil, scope: nil, url: nil, remote: true, method: "post", indexed: false, index: nil, **options, &block)
        url ||= polymorphic_path(model, {})
        model = model.last if model.is_a?(Array)
        utf_field = tag.input name: "utf8", type: "hidden", value: "&#x2713;", escape_attributes: false
        method_field = tag.input name: "_method", type: "hidden", value: "patch" if model && model.persisted?
        options = options.merge(action: url, "data-remote": remote, "accept-charset": "UTF-8", method: method)
        output = fields_with(model: model, scope: scope, indexed: indexed, index: index, &block)
        tag.form utf_field + method_field + output, options
      end

      def fields_with(model: nil, scope: nil, indexed: false, index: nil, &block)
        scope ||= model_name_from_record_or_class(model).param_key if model
        indexing = "[#{index}]" if index
        indexing ||= "[#{model.to_param}]" if indexed
        scope = "#{scope}#{indexing}".presence
        builder = FormWithBuilder.new(self, model, scope)
        block_given? ? capture(builder, &block) : ""
      end
    end
  end
end
