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
      output   =  js_debug(output, renderer.template.path) if @@debug_js && @lookup_context.rendered_format == :js
      output
    end

    # Direct access to partial rendering.
    def render_partial(context, options, &block) #:nodoc:
      renderer  =  PartialRenderer.new(@lookup_context)
      output    =  renderer.render(context, options, block)
      @partials << [renderer.template.path, output]
      output
    end

    private

    def js_debug(source, template_path)
      output =  parse_stack_trace()
      output << js_rails_info(source, template_path)
      output << <<-TRYCATCH
      try {
        #{source}
      } catch(e) {
        var srcOffset = #{output.lines.size};
        var errorInfo = railsPartialLookup(e, srcOffset);
        var error     = \"Rails: Javascript error in : \" + errorInfo[0] + "\\n";

        if (errorInfo[1] != null) {
          error = error + \"Rails: JS error at line: \\n\\n  \" + errorInfo[1] + "\\n\\n";
        }

        console.error(error, e);
      }
      TRYCATCH
    end

    def js_rails_info(source, template_path)
      output = <<-LOOKUP
      function railsPartialLookup(exception, srcOffset){
        var partial_map = {};\n
        var sourceLines = {};\n
        #{js_partial_infos(source).join("; \n")};
        #{js_source_info(source).join("; \n")};

        var sourcePath   = '#{template_path}';

        // Safari
        var lineNumber   = exception.line;
        var columnNumber = null;
        var sourceLine   = null;

        // Chrome
        if (lineNumber == undefined) {
          var offsets  = parseStackTrace(exception);
          lineNumber   = offsets[0];
          columnNumber = offsets[1];
        }

        lineNumber  = lineNumber - srcOffset - 1;
        var partial = partial_map[lineNumber];

        if (partial) {
          partialLineMatch = partial[2];
          partialPath      = partial[3];
          sourceLine       = partial[4];

          if (partialLineMatch) {
            var begLineColumn = partial[0];
            var endLineColumn = partial[1];

            if (columnNumber != null && columnNumber >= begLineColumn && columnNumber <= endLineColumn){
              sourcePath = partialPath;
            } else {
              sourceLine = sourceLines[lineNumber];
            }
          } else {
            sourcePath = partialPath;
          }
        }
        return [sourcePath, sourceLine];
      }\n\n
      LOOKUP
    end

    # Chrome doesn't define the line number in the exception on an arbitrary js snippet,
    # so it must be extracted from the stacktrace
    def parse_stack_trace
      output = <<-STACKPARSE
      function parseStackTrace(exception){\n
        var trace        = exception.stack.split("\\n");
        var info         = trace[1].match(/:(\\d+):(\\d+)\\)$/);
        var lineNumber   = info[1];
        var columnNumber = info[2];

        return [parseInt(lineNumber), parseInt(columnNumber)];
      }
      STACKPARSE

      output
    end

    def js_partial_infos(source)
      partial_info = []

      @partials.each do |partial_data|
        partial_output = partial_data[1]

        # First look for the escape version of the partial render
        beg_column = source.index(escape_javascript(partial_output))

        if beg_column
          partial_lines = escape_javascript(partial_output).lines.map(&:chomp)

        # No escaped version of the partial?  Maybe it's just a regular partial render
        else
          beg_column    = source.index(partial_output)
          partial_lines = partial_output.lines.map(&:chomp) if beg_column
        end


        if beg_column
          preceeding_code = source[0..beg_column]
          beg_line_number = preceeding_code.lines.length

          last_index      = partial_lines.size - 1
          partial_path    = partial_data[0]

          partial_escaped = Regexp.escape(partial_output)
          full_snippet    = source.scan(/^(.*)(#{partial_escaped})(.*)$/).flatten.join('').lines

          partial_lines.each_with_index do |line, index|
            line_number     = beg_line_number + index
            beg_line_column = index == 0 ? beg_column : 0
            end_line_column = line.length


            ### TODO
            ### partial_line_match isn't working; the 'line' var should represent the entire
            ### source line, not just the partial output

            # Is the partial output begin/end on the same line as the template
            source_line        = full_snippet[index]
            partial_line_match = partial_line_match?(beg_line_column, end_line_column, index, last_index, source_line)

            partial_info << "  partial_map['#{line_number}'] = [#{beg_line_column}, #{end_line_column}, #{partial_line_match}, '#{escape_javascript(partial_path)}', '#{escape_javascript(line)}']"
          end
        end
      end

      partial_info
    end

    def js_source_info(source)
      source_lines = source.lines
      source_info  = []

      source_lines.each_with_index do |source_line, index|
        source_info << "  sourceLines['#{index + 1}'] = '#{escape_javascript(source_line)}'"
      end

      source_info
    end


    def partial_line_match?(beg_column, end_column, index, last_index, source_line)
      if index == 0 && beg_column > 0
        true
      elsif last_index == index && end_column != source_line.length
        true
      else
        false
      end
    end
  end

end
