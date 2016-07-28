module ActionView
  module Helpers
    module FormWithHelper
      class FormWithBuilder
        include ActionView::Helpers::TagHelper

        FIELD_HELPERS = [:fields_for, :label, :check_box, :radio_button,
                        :hidden_field, :file_field, :text_field,
                        :password_field, :color_field, :search_field,
                        :telephone_field, :phone_field, :date_field,
                        :time_field, :datetime_field, :datetime_local_field,
                        :month_field, :week_field, :url_field, :email_field,
                        :number_field, :range_field]

        GENERATED_FIELD_HELPERS = FIELD_HELPERS - [:label, :check_box, :radio_button, :fields_for, :file_field, :text_area]

        attr_accessor :model, :scope, :url, :remote

        GENERATED_FIELD_HELPERS.each do |selector|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{selector}(method, *args, **options)                             # def text_field(method, *args, **options)
              tag.input options_for_field('#{selector}', method, args, options)   #   tag.input options_for_field(selector, method, args, options)
            end                                                                   # end
          RUBY_EVAL
        end

        def file_field(method, *args, **options)
          multiple = options.slice(:multiple)
          options = options_for(method, options).merge!(type: "file")
          options.merge!(multiple)
          tag.input options
        end

        def submit
          tag.input value: submit_default_value, "data-disable-with": submit_default_value, type: 'submit', name: 'commit'
        end

        def text_area(method, *args, **options)
          options = options_for(method, options)
          content = model.send(method) if model
          content = args[0] if args.size > 0
          content.nil? ? tag.textarea(options) : tag.textarea(content, options)
        end

        def label(method, *args, **options, &block)
          content ||= args[0] if args.size > 0
          content ||= I18n.t("#{model.model_name.i18n_key}.#{method}", default: "", scope: "helpers.label").presence if model && model.model_name
          content ||= translate_with_human_attribute_name(method)
          content ||= method.to_s.humanize
          content = @template.capture(content, &block) if block_given?
          tag.label content, options
        end

        def check_box(method, include_hidden: true, on: "1", off: "0", **options)
          hidden = "".html_safe
          options = options_for(method, options)
          checkbox_options = options.merge(type: 'checkbox', value: on)
          checkbox_options.merge!(checked: "checked") if model && checked?(on, model.send(method))
          include_hidden = false if off.nil?
          if include_hidden
            hidden_options = options.merge(type: 'hidden', value: off)
            hidden_options.delete(:checked)
            hidden = tag.input(hidden_options).html_safe
          end
          hidden + tag.input(checkbox_options).html_safe
        end

        def select(method, choices = nil, blank: nil, prompt: nil, index: :undefined, disabled: nil, **options, &block)
          tag.select option_tags_for_select(choices, blank: blank), options_for(method, options)
        end

        def collection_select(method, collection, value_method, text_method, blank: nil, prompt: nil, index: :undefined, disabled: nil, **options)
          choices = collection.map do |object|
            [object.send(value_method), object.send(text_method)]
          end
          select(method, choices, options)
        end

        def option_tags_for_select(choices, blank: false)
          result = (blank ? tag.option("", value: "") : "").html_safe
          result += choices.map do |choice|
            if choice.is_a? Array
              tag.option choice[0], value: choice[1]
            else
              tag.option choice, value: choice
            end
          end.join("\n").html_safe
          result
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

          def translate_with_human_attribute_name(method)
            model && model.class.respond_to?(:human_attribute_name) ? model.class.human_attribute_name(method) : nil
          end

          def submit_default_value
            if scope
              key    = model ? (model.persisted? ? :update : :create) : :submit
              model_name = if model.respond_to?(:model_name)
                model.model_name.human
              else
                scope.to_s.humanize
              end
              defaults = [:"helpers.submit.#{scope}.#{key}", :"helpers.submit.#{key}", :"#{key.to_s.humanize} #{model_name}"]
              I18n.t(defaults.shift, model: model_name, default: defaults)
            else
              I18n.t("helpers.submit.no_model")
            end
          end

          def name_for(method, options)
            scope = options.delete(:scope) { @scope }
            index = options.delete(:index)
            method = method.to_s.chomp("?")
            name = scope.to_s
            name += index ? "[#{index}]" : ""
            name += scope.nil? ? method : "[#{method}]"
            name += options.delete(:multiple) ? "[]" : "" #exception => file_field
          end

          def id_for(method, scope, **options)
            scope.nil? ? method : "#{scope}_#{method}"
          end

          def options_for(method, options) 
            options.reverse_merge!(name: name_for(method, options))
          end

          def options_for_field(selector, method, args, options)
            type = selector.split("_").first
            options = options_for(method, options)
            options.merge!(value: model.send(method)) if model && type != 'password'
            options.merge!(value: args[0]) if args.size > 0
            options[:size] = options[:maxlength] unless options.key?(:size)
            if placeholder = placeholder(options.delete(:placeholder), method)
              options.merge!(placeholder: placeholder)
            end
            options.reverse_merge!(type: type)
          end

          def placeholder(tag_value, method)
            if tag_value
              placeholder = tag_value if tag_value.is_a?(String)
              method_and_value = tag_value.is_a?(TrueClass) ? method : "#{method}.#{tag_value}"
              placeholder ||= Tags::Translator.new(model, scope, method_and_value, scope: "helpers.placeholder").translate
              placeholder ||= method.to_s.humanize
            end
          end

          def initialize(template, model, scope, url, remote, options)
            @template = template
            @model = model
            @scope = scope
            @url = url
            @remote = remote
          end
      end

      def form_with(model: nil, scope: nil, url: nil, remote: true, method: 'post', **options, &block)
        url ||= polymorphic_path(model, {})
        model = model.last if model.is_a?(Array)
        if model
          scope ||= model_name_from_record_or_class(model).param_key
        end
        builder = FormWithBuilder.new(self, model, scope, url, remote, options)
        inner_tags = tag.input name: "utf8", type: "hidden", value: "&#x2713;", escape_attributes: false
        inner_tags += tag.input name: "_method", type: "hidden", value: "patch" if model && model.persisted?
        output  = block_given? ? capture(builder, &block) : ""
        options = options.merge(action: url, "data-remote": remote, "accept-charset": "UTF-8", method: method)
        tag.form inner_tags + output, options
      end

      def fields_with(model: nil, scope: nil, remote: true, **options, &block)
        if model
          scope ||= model_name_from_record_or_class(model).param_key
        end
        builder = FormWithBuilder.new(self, model, scope, nil, remote, options)
        output  = capture(builder, &block)
        output
      end
    end
  end
end
