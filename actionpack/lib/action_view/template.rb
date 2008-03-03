module ActionView #:nodoc:
  class Template #:nodoc:

    attr_accessor :locals
    attr_reader :handler, :path, :source, :extension, :filename, :path_without_extension, :method

    def initialize(view, path_or_source, use_full_path, locals = {}, inline = false, inline_type = nil)
      @view = view
      @finder = @view.finder

      unless inline
        # Clear the forward slash at the beginning if exists
        @path = use_full_path ? path_or_source.sub(/^\//, '') : path_or_source
        @view.first_render ||= @path
        @source = nil # Don't read the source until we know that it is required
        set_extension_and_file_name(use_full_path)
      else
        @source = path_or_source
        @extension = inline_type
      end
      @locals = locals || {}
      @handler = @view.class.handler_class_for_extension(@extension).new(@view)
    end
    
    def render
      prepare!
      @handler.render(self)
    end

    def source
      @source ||= File.read(self.filename)
    end

    def method_key
      @method_key ||= (@filename || @source)
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
          unless @extension
            raise ActionViewError, "No template found for #{@path} in #{@finder.view_paths.inspect}"
          end
          @filename = @finder.pick_template(@path, @extension)
          @extension = @extension.gsub(/^.+\./, '') # strip off any formats
        end
      else
        @filename = @path
      end

      if @filename.blank?
        raise ActionViewError, "Couldn't find template file for #{@path} in #{@finder.view_paths.inspect}"
      end
    end

  end
end
