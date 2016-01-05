module ActionView
  module Template::Handlers
    class Raw
      def call(template)
        "#{template.source.inspect};"
      end
    end
  end
end
