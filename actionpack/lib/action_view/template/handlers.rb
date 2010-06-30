module ActionView #:nodoc:
  # = Action View Template Handlers
  class Template
    module Handlers #:nodoc:
      autoload :ERB, 'action_view/template/handlers/erb'
      autoload :RJS, 'action_view/template/handlers/rjs'
      autoload :Builder, 'action_view/template/handlers/builder'

      def self.extended(base)
        base.register_default_template_handler :erb, ERB
        base.register_template_handler :rjs, RJS
        base.register_template_handler :builder, Builder

        # TODO: Depreciate old template extensions
        base.register_template_handler :rhtml, ERB
        base.register_template_handler :rxml, Builder
      end

      @@template_handlers = {}
      @@default_template_handlers = nil
    
      def self.extensions
        @@template_extensions ||= @@template_handlers.keys
      end

      # Register a class that knows how to handle template files with the given
      # extension. This can be used to implement new template types.
      # The constructor for the class must take the ActiveView::Base instance
      # as a parameter, and the class must implement a +render+ method that
      # takes the contents of the template to render as well as the Hash of
      # local assigns available to the template. The +render+ method ought to
      # return the rendered template as a string.
      def register_template_handler(extension, klass)
        @@template_handlers[extension.to_sym] = klass
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

      def handler_class_for_extension(extension)
        (extension && registered_template_handler(extension.to_sym)) || @@default_template_handlers
      end
    end
  end
end
