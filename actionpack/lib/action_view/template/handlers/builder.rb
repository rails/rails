module ActionView
  module Template::Handlers
    class Builder
      # Default format used by Builder.
      class_attribute :default_format
      self.default_format = Mime::XML

      def call(template)
        require 'builder'
        "xml = ::Builder::XmlMarkup.new(:indent => 2);" +
          "self.output_buffer = xml.target!;" +
          template.source +
          ";xml.target!;"
      end
    end
  end
end
