module ActionView
  module Helpers
    module FormWithHelper

      class FormWithBuilder < FormBuilder

        FIELD_HELPERS = [:fields_for, :label, :check_box, :radio_button,
                        :hidden_field, :file_field, :text_area, :text_field,
                        :password_field, :color_field, :search_field,
                        :telephone_field, :phone_field, :date_field,
                        :time_field, :datetime_field, :datetime_local_field,
                        :month_field, :week_field, :url_field, :email_field,
                        :number_field, :range_field]

        GENERATED_FIELD_HELPERS = FIELD_HELPERS - [:label, :check_box, :radio_button, :fields_for, :hidden_field, :file_field]

        GENERATED_FIELD_HELPERS.each do |selector|
          tag_class_name = selector.to_s.camelize
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{selector}(method, *args, **options)  # def text_field(method, *args, **options)
              Tags::#{tag_class_name}.new(             #   @template.send(
                @object_name,                          #     "text_field",
                method,                                #     @object_name,
                @template,                             #     method,
                prepare_options(options, args[0]))     #     prepare_options(args[0], options))
              .render                                  #   @template.send(
            end                                        # end
          RUBY_EVAL
        end

        def check_box(method, *args, on: "1", off: "0", **options)
          Tags::CheckBox.new(@object_name, method, @template, on, off, prepare_options(options)).render
        end

        def select(method, choices = nil, blank: nil, prompt: nil, index: :undefined, disabled: nil, **html_options, &block)
          options = {}
          options[:include_blank] = blank if blank
          options[:prompt] = prompt if prompt
          options[:disabled] = disabled if disabled
          html_options[:index] = index unless index == :undefined
          Tags::Select.new(@object_name, method, @template, choices, options, prepare_options(html_options), &block).render
        end

        private

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
