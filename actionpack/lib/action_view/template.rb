module ActionView #:nodoc:
  class Template #:nodoc:

    attr_accessor :locals
    attr_reader :handler, :path, :extension, :filename, :path_without_extension, :method

    def initialize(view, path, use_full_path, locals = {})
      @view = view
      @finder = @view.finder

      # Clear the forward slash at the beginning if exists
      @path = use_full_path ? path.sub(/^\//, '') : path
      @view.first_render ||= @path
      @source = nil # Don't read the source until we know that it is required
      set_extension_and_file_name(use_full_path)
      
      @locals = locals || {}
      @handler = self.class.handler_class_for_extension(@extension).new(@view)
    end

    def render_template
      render
    rescue Exception => e
      raise e unless filename
      if TemplateError === e
        e.sub_template_of(filename)
        raise e
      else
        raise TemplateError.new(self, @view.assigns, e)
      end
    end
    
    def render
      prepare!
      @handler.render(self)
    end

    def source
      @source ||= File.read(self.filename)
    end

    def method_key
      @filename
    end

    def base_path_for_exception
      @finder.find_base_path_for("#{@path_without_extension}.#{@extension}") || @finder.view_paths.first
    end
    
    def prepare!
      @view.send :evaluate_assigns
      @view.current_render_extension = @extension
      
      if @handler.compilable?
        @handler.compile_template(self) # compile the given template, if necessary
        @method = @view.method_names[method_key] # Set the method name for this template and run it
      end
    end

    private

    def set_extension_and_file_name(use_full_path)
      @path_without_extension, @extension = @finder.path_and_extension(@path)
      if use_full_path
        if @extension
          @filename = @finder.pick_template(@path_without_extension, @extension)
        else
          @extension = @finder.pick_template_extension(@path).to_s
          raise_missing_template_exception unless @extension
          
          @filename = @finder.pick_template(@path, @extension)
          @extension = @extension.gsub(/^.+\./, '') # strip off any formats
        end
      else
        @filename = @path
      end

      raise_missing_template_exception if @filename.blank?
    end
    
    def raise_missing_template_exception
      full_template_path = @path.include?('.') ? @path : "#{@path}.#{@view.template_format}.erb"
      display_paths = @finder.view_paths.join(':')
      template_type = (@path =~ /layouts/i) ? 'layout' : 'template'
      raise(MissingTemplate, "Missing #{template_type} #{full_template_path} in view path #{display_paths}")
    end

    # Template Handlers
    
    @@template_handlers = HashWithIndifferentAccess.new
    @@default_template_handlers = nil
    
    # Register a class that knows how to handle template files with the given
    # extension. This can be used to implement new template types.
    # The constructor for the class must take the ActiveView::Base instance
    # as a parameter, and the class must implement a +render+ method that
    # takes the contents of the template to render as well as the Hash of
    # local assigns available to the template. The +render+ method ought to
    # return the rendered template as a string.
    def self.register_template_handler(extension, klass)
      @@template_handlers[extension.to_sym] = klass
      TemplateFinder.update_extension_cache_for(extension.to_s)
    end

    def self.template_handler_extensions
      @@template_handlers.keys.map(&:to_s).sort
    end

    def self.register_default_template_handler(extension, klass)
      register_template_handler(extension, klass)
      @@default_template_handlers = klass
    end

    def self.handler_class_for_extension(extension)
      (extension && @@template_handlers[extension.to_sym]) || @@default_template_handlers
    end

    register_default_template_handler :erb, TemplateHandlers::ERB
    register_template_handler :rjs, TemplateHandlers::RJS
    register_template_handler :builder, TemplateHandlers::Builder

    # TODO: Depreciate old template extensions
    register_template_handler :rhtml, TemplateHandlers::ERB
    register_template_handler :rxml, TemplateHandlers::Builder
    
  end
end
