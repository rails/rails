module ActionView
  module Helpers
    module FormWithHelper

      DEFAULT_SCOPE = "form"

      class FormWithBuilder < FormBuilder

        FIELD_HELPERS = [:fields_for, :label, :text_field, :password_field,
                        :hidden_field, :file_field, :text_area, :check_box,
                        :radio_button, :color_field, :search_field,
                        :telephone_field, :phone_field, :date_field,
                        :time_field, :datetime_field, :datetime_local_field,
                        :month_field, :week_field, :url_field, :email_field,
                        :number_field, :range_field]

        GENERATED_FIELD_HELPERS = field_helpers - [:label, :check_box, :radio_button, :fields_for, :hidden_field, :file_field]

        GENERATED_FIELD_HELPERS.each do |selector|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{selector}(method, *args, **options)  # def text_field(method, *args, **options)
              @template.send(                          #   @template.send(
                #{selector.inspect},                   #     "text_field",
                @object_name,                          #     @object_name,
                method,                                #     method,
                prepare_options(args, options))        #     prepare_options(args, options))
            end                                        # end
          RUBY_EVAL
        end

        def check_box(method, *args, on: "1", off: "0", **options)
          @template.check_box(@object_name, method, prepare_options(args, options), on, off)
        end

        private

          def prepare_options(args, options)
            options = {id: nil}.merge(options)
            options[:value] = args[0] if args.size > 0
            objectify_options(options)
          end

      end

      def form_with(model: nil, scope: nil, url: nil, remote: true, **options, &block)
        if model.nil?
          model_name = scope || DEFAULT_SCOPE
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
