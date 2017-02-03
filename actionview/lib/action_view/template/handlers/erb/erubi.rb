require "erubi"

module ActionView
  class Template
    module Handlers
      class ERB
        class Erubi < ::Erubi::Engine
          # :nodoc: all
          def initialize(input, properties = {})
            @newline_pending = 0

            # Dup properties so that we don't modify argument
            properties = Hash[properties]
            properties[:preamble]   = "@output_buffer = output_buffer || ActionView::OutputBuffer.new;"
            properties[:postamble]  = "@output_buffer.to_s"
            properties[:bufvar]     = "@output_buffer"
            properties[:escapefunc] = ""

            super
          end

          def evaluate(action_view_erb_handler_context)
            pr = eval("proc { #{@src} }", binding, @filename || "(erubi)")
            action_view_erb_handler_context.instance_eval(&pr)
          end

        private
          def add_text(text)
            return if text.empty?

            if text == "\n"
              @newline_pending += 1
            else
              src << "@output_buffer.safe_append='"
              src << "\n" * @newline_pending if @newline_pending > 0
              src << text.gsub(/['\\]/, '\\\\\&')
              src << "'.freeze;"

              @newline_pending = 0
            end
          end

          BLOCK_EXPR = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

          def add_expression(indicator, code)
            flush_newline_if_pending(src)

            if (indicator == "==") || @escape
              src << "@output_buffer.safe_expr_append="
            else
              src << "@output_buffer.append="
            end

            if BLOCK_EXPR.match?(code)
              src << " " << code
            else
              src << "(" << code << ");"
            end
          end

          def add_code(code)
            flush_newline_if_pending(src)
            super
          end

          def add_postamble(_)
            flush_newline_if_pending(src)
            super
          end

          def flush_newline_if_pending(src)
            if @newline_pending > 0
              src << "@output_buffer.safe_append='#{"\n" * @newline_pending}'.freeze;"
              @newline_pending = 0
            end
          end
        end
      end
    end
  end
end
