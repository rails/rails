module ActionView
  module TemplateHandlers
    class RJS < TemplateHandler
      def self.line_offset
        2
      end

      def compile(template)
        "controller.response.content_type ||= Mime::JS\n" +
        "update_page do |page|\n#{template}\nend"
      end
    end
  end
end
