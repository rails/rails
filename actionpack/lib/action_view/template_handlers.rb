module ActionView #:nodoc:
  module TemplateHandlers #:nodoc:
    autoload :ERB, 'action_view/template_handlers/erb'
    autoload :RJS, 'action_view/template_handlers/rjs'
    autoload :Builder, 'action_view/template_handlers/builder'

    def self.extended(base)
      base.register_default_template_handler :erb, TemplateHandlers::ERB
      base.register_template_handler :rjs, TemplateHandlers::RJS
      base.register_template_handler :builder, TemplateHandlers::Builder

      # TODO: Depreciate old template extensions
      base.register_template_handler :rhtml, TemplateHandlers::ERB
      base.register_template_handler :rxml, TemplateHandlers::Builder
    end

    @@template_handlers = {}
    @@default_template_handlers = nil

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
      @@template_handlers.keys.map(&:to_s).sort
    end

    def registered_template_handler(extension)
      extension && @@template_handlers[extension.to_sym]
    end

    def register_default_template_handler(extension, klass)
      register_template_handler(extension, klass)
      @@default_template_handlers = klass
    end

    def handler_class_for_extension(extension)
      registered_template_handler(extension) || @@default_template_handlers
    end
  end
end
