module ActionView
  module TemplateHandlers
    class Builder < TemplateHandler
      include Compilable

      self.default_format = Mime::XML

      def compile(template)
        require 'builder'
        "xml = ::Builder::XmlMarkup.new(:indent => 2);" +
          "self.output_buffer = xml.target!;" +
          template.source +
          ";xml.target!;"
      end
    end
  end
end
