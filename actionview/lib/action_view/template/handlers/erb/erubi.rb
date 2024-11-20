# frozen_string_literal: true

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

            properties[:bufvar]     ||= "@output_buffer"
            properties[:preamble]   ||= ""
            properties[:postamble]  ||= "#{properties[:bufvar]}"

            # Tell Eruby that whether template will be compiled with `frozen_string_literal: true`
            properties[:freeze_template_literals] = !Template.frozen_string_literal

            properties[:escapefunc] = ""

            super
          end

        private
          def add_text(text)
            return if text.empty?

            if text == "\n"
              @newline_pending += 1
            else
              with_buffer do
                src << ".safe_append='"
                src << "\n" * @newline_pending if @newline_pending > 0
                src << text.gsub(/['\\]/, '\\\\\&') << @text_end
              end
              @newline_pending = 0
            end
          end

          BLOCK_EXPR = /((\s|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

          def add_expression(indicator, code)
            flush_newline_if_pending(src)

            with_buffer do
              if (indicator == "==") || @escape
                src << ".safe_expr_append="
              else
                src << ".append="
              end

              if BLOCK_EXPR.match?(code)
                src << " " << code
              else
                src << "(" << code << ")"
              end
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
              with_buffer { src << ".safe_append='#{"\n" * @newline_pending}" << @text_end }
              @newline_pending = 0
            end
          end
        end
      end
    end
  end
end
