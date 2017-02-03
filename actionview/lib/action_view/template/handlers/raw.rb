module ActionView
  module Template::Handlers
    class Raw
      def call(template)
        "#{template.source.inspect}.html_safe;"
      end
    end
  end
end
