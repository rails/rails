module ActionView
  # This is the main entry point for rendering. It basically delegates
  # to other objects like TemplateRenderer and PartialRenderer which
  # actually renders the template.
  #
  # The Renderer will parse the options from the +render+ or +render_body+
  # method and render a partial or a template based on the options. The
  # +TemplateRenderer+ and +PartialRenderer+ objects are wrappers which do all
  # the setup and logic necessary to render a view and a new object is created
  # each time +render+ is called.
  class Renderer
    include ActionView::Helpers::JavaScriptHelper

    attr_accessor :lookup_context
    cattr_accessor :debug_js

    def initialize(lookup_context)
      @lookup_context = lookup_context
      @partials = []
    end

    # Main render entry point shared by AV and AC.
    def render(context, options)
      if options.key?(:partial)
        render_partial(context, options)
      else
        render_template(context, options)
      end
    end

    # Render but returns a valid Rack body. If fibers are defined, we return
    # a streaming body that renders the template piece by piece.
    #
    # Note that partials are not supported to be rendered with streaming,
    # so in such cases, we just wrap them in an array.
    def render_body(context, options)
      if options.key?(:partial)
        [render_partial(context, options)]
      else
        StreamingTemplateRenderer.new(@lookup_context).render(context, options)
      end
    end

    # Direct accessor to template rendering.
    def render_template(context, options) #:nodoc:
      renderer =  TemplateRenderer.new(@lookup_context)
      output   =  renderer.render(context, options)
      output   =  js_debug(output, renderer.path) if @@debug_js && @lookup_context.rendered_format == :js
      output
    end

    # Direct access to partial rendering.
    def render_partial(context, options, &block) #:nodoc:
      renderer  =  PartialRenderer.new(@lookup_context)
      output    =  renderer.render(context, options, block)
      @partials << [renderer.path, output]
      output
    end

    private

    def js_debug(source, template_path)
      output = js_rails_info(source, template_path)

      output << "try { #{source} }catch(e){ console.error(\"Rails: Javascript error in \" + railsJsInfo(e) , e); };"
      output
    end

    def js_rails_info(source, template_path)
      output = "function railsJsInfo(exception){\n"
      output << "  var partial_map = {};\n"

      partial_info = js_partial_infos(source)

      output << partial_info.join("; \n")
      output << <<-LOOKUP
        var sourcePath     = '#{template_path}';
        var sourceFragment = '';

        partial = partial_map[exception.lineNumber];

        if (partial){
          partialLineMatch  = partial[2];
          partialPath       = partial[3];
          partialOutput     = partial[4];

          sourcePath        = partialPath;

          if (partialLineMatch) {
            sourcePath = sourcePath + " or " + partialPath
          }
        }

        return sourcePath;
      LOOKUP

      output << "}\n\n"
    end

    def js_partial_infos(source)
      partial_info = []

      puts "-----------------------"
      puts @partials.inspect
      puts "-----------------------"

      @partials.each do |partial_data|

        partial_output = partial_data[1]
        beg_column     = source.index(partial_output) || source.index(escape_javascript(partial_output))
        source_lines   = source.split(/\r?\n/)

        if beg_column
          partial_path    = partial_data[0]
          preceeding_code = source[0..source_index]

          beg_line_number = preceeding_code.scan(/\r?\n/).length
          partial_lines   = partial_output.split(/\r?\n/)

          partial_lines.each_with_index do |line, i|
            line_number = beg_line_number + i
            source_line = source_lines[line_number].length

            beg_column  = source_lines[line_number].index(line)
            end_column  = line.length

            # Is the partial output begin/end on the same line as the template
            partial_line_match = (beg_column > 0 || end_column != source_line.length) ? true : false

            partial_info << "  partial_map['#{line_number}'] = [#{beg_column}, #{end_column}, #{partial_line_match}, '#{escape_javascript(partial_path)}', '#{escape_javascript(partial_output)}']"
          end
        end

      end
      partial_info
    end
  end

end
