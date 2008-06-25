module ActionView #:nodoc:
  class Template #:nodoc:
    extend TemplateHandlers

    attr_accessor :locals
    attr_reader :handler, :path, :extension, :filename, :method

    def initialize(view, path, use_full_path, locals = {})
      @view = view
      @paths = view.view_paths

      @original_path = path
      @path = TemplateFile.from_path(path, !use_full_path)
      @view.first_render ||= @path.to_s
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

    def path_without_extension
      @path.path_without_extension
    end

    def source
      @source ||= File.read(self.filename)
    end

    def method_key
      @filename
    end

    def base_path_for_exception
      (@paths.find_load_path_for_path(@path) || @paths.first).to_s
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
        @extension = @path.extension

        if use_full_path
          unless @extension
            @path = @view.send(:template_file_from_name, @path)
            raise_missing_template_exception unless @path
            @extension = @path.extension
          end

          if @path = @paths.find_template_file_for_path(path)
            @filename = @path.full_path
            @extension = @path.extension
          end
        else
          @filename = @path.full_path
        end

        raise_missing_template_exception if @filename.blank?
      end

      def raise_missing_template_exception
        full_template_path = @original_path.include?('.') ? @original_path : "#{@original_path}.#{@view.template_format}.erb"
        display_paths = @paths.join(':')
        template_type = (@original_path =~ /layouts/i) ? 'layout' : 'template'
        raise(MissingTemplate, "Missing #{template_type} #{full_template_path} in view path #{display_paths}")
      end
  end
end
