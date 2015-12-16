module ActionView
  module Template::Handlers
    class Raw
      def call(template)
        escaped = template.source.gsub(':'.freeze, '\:'.freeze)

        '%q:' + escaped + ':;'
      end
    end
  end
end
