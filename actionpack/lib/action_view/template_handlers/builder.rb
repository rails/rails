require 'builder'

module ActionView
  module TemplateHandlers
    class Builder < TemplateHandler
      include Compilable

      def compile(template)
        "controller.response.content_type ||= Mime::XML;" +
          "xml = ::Builder::XmlMarkup.new(:indent => 2);" +
          template.source +
          ";xml.target!;"
      end

      def cache_fragment(block, name = {}, options = nil)
        @view.fragment_for(block, name, options) do
          eval('xml.target!', block.binding)
        end
      end
    end
  end
end
