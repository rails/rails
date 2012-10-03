module ActionView #:nodoc:
  # = Action View Template Handlers
  class Template
    module Handlers #:nodoc:
      autoload :ERB, 'action_view/template/handlers/erb'
      autoload :Builder, 'action_view/template/handlers/builder'
      autoload :Raw, 'action_view/template/handlers/raw'

      def self.extended(base)
        base.register_default_template_handler :erb, ERB.new
        base.register_template_handler :builder, Builder.new
        base.register_template_handler :raw, Raw.new
        base.register_template_handler :ruby, :source.to_proc
      end

      @@template_handlers = {}
      @@default_template_handlers = nil

      def self.extensions
        @@template_extensions ||= @@template_handlers.keys
      end

      # Register an object that knows how to handle template files with the given
      # extensions. This can be used to implement new template types.
      # The handler must respond to `:call`, which will be passed the template
      # and should return the rendered template as a String.
      def register_template_handler(*extensions, handler)
        raise(ArgumentError, "Extension is required") if extensions.empty?
        extensions.each do |extension|
          @@template_handlers[extension.to_sym] = handler
        end
        @@template_extensions = nil
      end

      def template_handler_extensions
        @@template_handlers.keys.map {|key| key.to_s }.sort
      end

      def registered_template_handler(extension)
        extension && @@template_handlers[extension.to_sym]
      end

      def register_default_template_handler(extension, klass)
        register_template_handler(extension, klass)
        @@default_template_handlers = klass
      end

      def handler_for_extension(extension)
        registered_template_handler(extension) || @@default_template_handlers
      end
    end
  end
end
