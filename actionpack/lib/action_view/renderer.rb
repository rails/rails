module ActionView
  module Renderer
    # TODO: Local assigns should not be tied to template instance
    attr_accessor :locals

    # TODO: These readers should be private
    attr_reader :filename, :source, :handler, :method_key, :method

    def render
      prepare!
      @handler.render(self)
    end

    private
      def prepare!
        unless @prepared
          @view.send(:evaluate_assigns)
          @view.current_render_extension = @extension

          if @handler.compilable?
            @handler.compile_template(self) # compile the given template, if necessary
            @method = @view.method_names[method_key] # Set the method name for this template and run it
          end

          @prepared = true
        end
      end
  end
end
