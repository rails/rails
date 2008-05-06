module ActionView
  module TemplateHandlers
    class RJS < TemplateHandler
      include Compilable

      def self.line_offset
        2
      end

      def compile(template)
        "controller.response.content_type ||= Mime::JS\n" +
        "update_page do |page|\n#{template.source}\nend"
      end

      def cache_fragment(block, name = {}, options = nil) #:nodoc:
        @view.fragment_for(block, name, options) do
          begin
            debug_mode, ActionView::Base.debug_rjs = ActionView::Base.debug_rjs, false
            eval('page.to_s', block.binding)
          ensure
            ActionView::Base.debug_rjs = debug_mode
          end
        end
      end
    end
  end
end
