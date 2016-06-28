# Consideration:
# * scope/prefix/object_name when url with no scope?
# * Allow form fields that do not correspond to model attributes - how? f.input scope: 'other'
# * Implement own builder

module ActionView
  module Helpers
    module FormWithHelper

      DEFAULT_SCOPE = "form"

      def form_with(model: nil, scope: nil, url: nil, remote: true, **options, &block)
        if !model.nil?
          model_name = model_name_from_record_or_class(model).param_key
          url = url || polymorphic_path(model, {})
        else
          model_name = scope || DEFAULT_SCOPE
        end

        opts = {remote: remote}.merge(options)
        builder = instantiate_builder(model_name, model, options)
        output  = capture(builder, &block)
        html_options = html_options_for_form(url || {}, options.merge(opts))
        form_tag_with_body(html_options, output)
      end
    end
  end
end
