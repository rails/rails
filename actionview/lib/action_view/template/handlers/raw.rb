module ActionView
  module Template::Handlers
    class Raw
      def call(template)
        escaped = template.source.gsub(/:/, '\:')

        '%q:' + escaped + ':;'
      end
    end
  end
end
