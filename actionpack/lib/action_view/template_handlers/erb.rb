require 'erubis'

module ActionView
  module TemplateHandlers
    class Erubis < ::Erubis::Eruby
      def add_preamble(src)
        @newline_pending = 0
        src << "@output_buffer = ActionView::OutputBuffer.new;"
      end

      def add_text(src, text)
        return if text.empty?

        if text == "\n"
          @newline_pending += 1
        else
          src << "@output_buffer.safe_append='"
          src << "\n" * @newline_pending if @newline_pending > 0
          src << escape_text(text) << "';"

          @newline_pending = 0
        end
      end

      BLOCK_EXPR = /\s+(do|\{)(\s*\|[^|]*\|)?\s*\Z/

      def add_expr_literal(src, code)
        flush_newline_if_pending(src)
        if code =~ BLOCK_EXPR
          # In rails3, block helpers return strings, so they simply:
          #
          #   src << '@output_buffer.append= ' << code
          #
          # But in rails2, block helpers use capture. We still want to
          # support the new syntax, so we silently convert any
          # <%= helper do %> to <% helper do %> for forward compatibility.
          add_stmt(src, code)
        else
          src << '@output_buffer.append=(' << code << ');'
        end
      end

      def add_expr_escaped(src, code)
        flush_newline_if_pending(src)
        if code =~ BLOCK_EXPR
          # src << "@output_buffer.safe_append= " << code
          fail '<%== not supported before Rails3'
        else
          src << "@output_buffer.safe_concat((" << code << ").to_s);"
        end
      end

      def add_postamble(src)
        flush_newline_if_pending(src)
        src << '@output_buffer.to_s'
      end

      def flush_newline_if_pending(src)
        if @newline_pending > 0
          src << "@output_buffer.safe_append='#{"\n" * @newline_pending}';"
          @newline_pending = 0
        end
      end
    end

    class ERB < TemplateHandler
      include Compilable

      # Specify trim mode for the ERB compiler. Defaults to '-'.
      # See ERb documentation for suitable values.
      cattr_accessor :erb_trim_mode
      self.erb_trim_mode = '-'

      # Default implementation used.
      cattr_accessor :erb_implementation
      self.erb_implementation = Erubis

      ENCODING_TAG = Regexp.new("\\A(<%#{ENCODING_FLAG}-?%>)[ \\t]*")

      def compile(template)
        erb = "<% __in_erb_template=true %>#{template.source}"

        if erb.respond_to?(:force_encoding)
          erb.force_encoding(template.source.encoding)
        end

        self.class.erb_implementation.new(
          erb,
          :trim => (self.class.erb_trim_mode == "-")
        ).src
      end
    end
  end
end
