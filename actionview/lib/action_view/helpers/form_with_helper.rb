module ActionView
  module Helpers
    module FormWithHelper
      def form_with(model: nil, scope: nil, url: nil, remote: true, html_class: nil, id: nil, **options, &block)
        opts = {html: {class: html_class, id: id}.merge(options), remote: remote}
        form_for(model, opts, &block)
      end
    end
  end
end
