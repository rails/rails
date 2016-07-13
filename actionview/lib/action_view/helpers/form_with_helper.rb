module ActionView
  module Helpers
    module FormWithHelper
      class FormWithBuilder < FormBuilder

        include ActionView::Helpers::TagHelper

        FIELD_HELPERS = [:fields_for, :label, :check_box, :radio_button,
                        :hidden_field, :file_field, :text_field,
                        :password_field, :color_field, :search_field,
                        :telephone_field, :phone_field, :date_field,
                        :time_field, :datetime_field, :datetime_local_field,
                        :month_field, :week_field, :url_field, :email_field,
                        :number_field, :range_field]

        GENERATED_FIELD_HELPERS = FIELD_HELPERS - [:label, :check_box, :radio_button, :fields_for, :hidden_field, :file_field, :text_area]

        GENERATED_FIELD_HELPERS.each do |selector|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{selector}(method, *args, **options)                   # def text_field(method, *args, **options)
              tag.input options_for_field(method, args, options)        #   tag.input options_for_field(method, args, options)
            end                                                         # end
          RUBY_EVAL
        end

        def text_area(method, *args, **options)
          options = options_for(method, options)
          content = object.send(method) if object
          content = args[0] if args.size > 0
          content.nil? ? tag.textarea(options) : tag.textarea(content, options)
        end

        def label(method, content, **options)
          options = options.dup
          scope = options.delete(:scope) { object_name }
          tag.label content, options.reverse_merge(for: id_for(method, scope, options))
        end

        def check_box(method, *args, on: "1", off: "0", **options)
          Tags::CheckBox.new(@object_name, method, @template, on, off, prepare_options(options)).render
        end

        def select(method, choices = nil, blank: nil, prompt: nil, index: :undefined, disabled: nil, **options, &block)
          tag.select option_tags_for_select(choices, blank: blank), options_for(method, options)
        end

        def collection_select(method, collection, value_method, text_method, blank: nil, prompt: nil, index: :undefined, disabled: nil, **html_options)
          options = prepare_select_options(html_options, blank, prompt, index, disabled)
          html_options = prepare_options(html_options)
          html_options.delete(:object)
          Tags::CollectionSelect.new(@object_name, method, @template, collection, value_method, text_method, options, html_options).render
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

          def prepare_select_options(html_options, blank, prompt, index, disabled)
            options = {}
            options[:include_blank] = blank if blank 
            options[:prompt] = prompt if prompt
            options[:disabled] = disabled if disabled
            html_options[:index] = index unless index == :undefined
            options
          end

          def prepare_options(options, value = nil)
            options[:scope] = nil if @object_name.nil?
            options = {id: nil}.merge(options)
            options[:value] = value if value
            objectify_options(options)
          end

          def submit_default_value
            if @object_name
              super
            else
              I18n.t("helpers.submit.no_model")
            end
          end

          def name_for(method, scope, **options)
            scope.nil? ? method : "#{scope}[#{method}]"
          end

          def id_for(method, scope, **options)
            scope.nil? ? method : "#{scope}_#{method}"
          end

          def options_for(method, options)
            options = options.dup
            scope = options.delete(:scope) { object_name }
            options.reverse_merge!(name: name_for(method, scope, options))
          end

          def options_for_field(method, args, options)
            options = options_for(method, options)
            options.merge!(value: object.send(method)) if object
            options.merge!(value: args[0]) if args.size > 0
            options.merge!(type: 'text')
          end

          def initialize(object_name, object, template, options)
            super
          end

      end

      def form_with(model: nil, scope: nil, url: nil, remote: true, **options, &block)
        if model.nil?
          model_name = scope
        else
          model_name = model_name_from_record_or_class(model).param_key
          url = url || polymorphic_path(model, {})
        end

        opts = {remote: remote}.merge(options)
        builder = FormWithBuilder.new(model_name, model, self, options)
        output  = capture(builder, &block)
        html_options = html_options_for_form(url || {}, options.merge(opts))
        form_tag_with_body(html_options, output)
      end

    end
  end
end
