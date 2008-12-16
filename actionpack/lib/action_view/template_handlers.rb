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

    def valid_extension?(extension)
      template_handler_extensions.include?(extension) || init_path_for_extension(extension)
    end

    def template_handler_extensions
      @@template_handlers.keys.map(&:to_s).sort
    end

    def register_default_template_handler(extension, klass)
      register_template_handler(extension, klass)
      @@default_template_handlers = klass
    end

    def handler_class_for_extension(extension)
      (extension && @@template_handlers[extension.to_sym] || autoload_handler_class(extension)) ||
        @@default_template_handlers
    end

    private
      def autoload_handler_class(extension)
        return if Gem.loaded_specs[extension]
        return unless init_path = init_path_for_extension(extension)
        Gem.activate(extension)
        load(init_path)
        handler_class_for_extension(extension)
      end

      # Returns the path to the rails/init.rb file for the given extension,
      # or nil if no gem provides it.
      def init_path_for_extension(extension)
        return unless spec = Gem.searcher.find(extension.to_s)
        returning File.join(spec.full_gem_path, 'rails', 'init.rb') do |path|
          return unless File.file?(path)
        end
      end
  end
end
