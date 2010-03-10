module ActionView
  module Helpers
    module DeprecatedBlockHelpers
      extend ActiveSupport::Concern

      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::JavaScriptHelper
      include ActionView::Helpers::FormHelper

      def content_tag(*, &block)
        block_called_from_erb?(block) ? safe_concat(super) : super
      end

      def javascript_tag(*, &block)
        block_called_from_erb?(block) ? safe_concat(super) : super
      end

      def form_for(*, &block)
        block_called_from_erb?(block) ? safe_concat(super) : super
      end

      def form_tag(*, &block)
        block_called_from_erb?(block) ? safe_concat(super) : super
      end

      def fields_for(*, &block)
        block_called_from_erb?(block) ? safe_concat(super) : super
      end

      def field_set_tag(*, &block)
        block_called_from_erb?(block) ? safe_concat(super) : super
      end

      BLOCK_CALLED_FROM_ERB = 'defined? __in_erb_template'

      if RUBY_VERSION < '1.9.0'
        # Check whether we're called from an erb template.
        # We'd return a string in any other case, but erb <%= ... %>
        # can't take an <% end %> later on, so we have to use <% ... %>
        # and implicitly concat.
        def block_called_from_erb?(block)
          block && eval(BLOCK_CALLED_FROM_ERB, block)
        end
      else
        def block_called_from_erb?(block)
          block && eval(BLOCK_CALLED_FROM_ERB, block.binding)
        end
      end
    end
  end
end