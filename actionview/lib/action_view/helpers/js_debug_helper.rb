module ActionView
  module Helpers
    module JSDebugHelper

      def js_debug(source, template_path)
        output = parse_stack_trace()
        output << js_rails_info(source, template_path)
        output << <<-TRYCATCH
        try {
          #{source}
        } catch(e) {
          var srcOffset = #{output.lines.size};
          var errorInfo = railsPartialLookup(e, srcOffset);
          var error     = \"Rails: Javascript error in : \" + errorInfo[0] + "\\n";

          if (errorInfo[1] != null) {
            error = error + \"Error at line: \\n\\n  \" + errorInfo[1] + "\\n\\n";
          }

          console.error(error, e);
        }
        TRYCATCH
      end

      def js_rails_info(source, template_path)
        <<-LOOKUP
        function railsPartialLookup(exception, srcOffset){
          var partial_map = {};\n
          var sourceLines = {};\n
          #{partial_infos(source).join("; \n")};
          #{source_info(source).join("; \n")};

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
        <<-STACKPARSE
        function parseStackTrace(exception){\n
          var trace        = exception.stack.split("\\n");
          var info         = trace[1].match(/:(\\d+):(\\d+)\\)$/);
          var lineNumber   = info[1];
          var columnNumber = info[2];

          return [parseInt(lineNumber), parseInt(columnNumber)];
        }
        STACKPARSE
      end

      def partial_infos(source)
        partial_info = []

        @partials.each do |partial_data|
          partial_output = partial_data[1]

          # First look for the escape version of the partial render
          beg_column = source.index(escape_javascript(partial_output))

          if beg_column
            partial_lines = escape_javascript(partial_output).lines.map(&:chomp)

            # No escaped version of the partial?  Maybe it's just a regular partial render
          else
            beg_column = source.index(partial_output)
            partial_lines = partial_output.lines.map(&:chomp) if beg_column
          end


          if beg_column
            preceeding_code = beg_column > 1 ? source[0..beg_column - 1] : " "
            beg_line_number = preceeding_code.lines.length

            last_index      = partial_lines.size - 1
            partial_path    = partial_data[0]

            # Extract the entire source snippet; e.g. the partial output
            #  plus any code that preceeds/follows on the same lines
            partial_escaped = Regexp.escape(partial_output)
            full_snippet = source.scan(/^(.*)(#{partial_escaped})(.*)$/).flatten.join('').lines

            partial_lines.each_with_index do |line, index|
              line_number = beg_line_number + index
              beg_line_column = index == 0 ? beg_column : 0
              end_line_column = line.length
              source_line = full_snippet[index]

              partial_line_match = partial_line_match?(beg_line_column, end_line_column, index, last_index, source_line)

              partial_info << "  partial_map['#{line_number}'] = [#{beg_line_column}, #{end_line_column}, #{partial_line_match}, '#{escape_javascript(partial_path)}', '#{escape_javascript(line)}']"
            end
          end
        end

        partial_info
      end

      def source_info(source)
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
end