module ActionView
  module Helpers
    module FormWithHelper

      def form_with(model: nil, scope: nil, url: nil, remote: true, **options, &block)
        if !model.nil?
          opts = {html: {class: options[:class], id: options[:id]}.merge(options), remote: remote}
          form_for(model, opts, &block)
        else
          opts = {remote: remote}.merge(options)
          form_tag(url, opts, &block)
        end
      end
    end
  end
end
