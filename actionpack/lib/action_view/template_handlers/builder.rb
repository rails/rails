require 'builder'

module ActionView
  module TemplateHandlers
    class Builder < TemplateHandler
      include Compilable

      def compile(template)
        # ActionMailer does not have a response
        "controller.respond_to?(:response) && controller.response.content_type ||= Mime::XML;" +
          "xml = ::Builder::XmlMarkup.new(:indent => 2);" +
          "self.output_buffer = xml.target!;" +
          template.source +
          ";xml.target!;"
      end
    end
  end
end
