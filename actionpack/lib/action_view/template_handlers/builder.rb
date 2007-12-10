require 'builder'

module ActionView
  module TemplateHandlers
    class Builder < TemplateHandler
      def self.line_offset
        2
      end

      def compile(template)
        content_type_handler = (@view.send!(:controller).respond_to?(:response) ? "controller.response" : "controller")
        "#{content_type_handler}.content_type ||= Mime::XML\n" +
        "xml = Builder::XmlMarkup.new(:indent => 2)\n" +
        template +
        "\nxml.target!\n"
      end
    end
  end
end
