require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/string/output_safety'
require "action_view/template"
require 'erubis'

module ActionView
  class OutputBuffer < ActiveSupport::SafeBuffer
    def <<(value)
      super(value.to_s)
    end
    alias :append= :<<

    def append_if_string=(value)
      if value.is_a?(String) && !value.is_a?(NonConcattingString)
        ActiveSupport::Deprecation.warn("<% %> style block helpers are deprecated. Please use <%= %>", caller)
        self << value
      end
    end
  end

  class Template
    module Handlers
      class Erubis < ::Erubis::Eruby
        def add_preamble(src)
          src << "@output_buffer = ActionView::OutputBuffer.new;"
        end

        def add_text(src, text)
          return if text.empty?
          src << "@output_buffer.safe_concat('" << escape_text(text) << "');"
        end

        BLOCK_EXPR = /\s+(do|\{)(\s*\|[^|]*\|)?\s*\Z/

        def add_expr_literal(src, code)
          if code =~ BLOCK_EXPR
            src << '@output_buffer.append= ' << code
          else
            src << '@output_buffer.append= (' << code << ');'
          end
        end

        def add_stmt(src, code)
          if code =~ BLOCK_EXPR
            src << '@output_buffer.append_if_string= ' << code
          else
            super
          end
        end

        def add_expr_escaped(src, code)
          src << '@output_buffer.append= ' << escaped_expr(code) << ';'
        end

        def add_postamble(src)
          src << '@output_buffer.to_s'
        end
      end

      class ERB < Handler
        include Compilable

        ##
        # :singleton-method:
        # Specify trim mode for the ERB compiler. Defaults to '-'.
        # See ERb documentation for suitable values.
        cattr_accessor :erb_trim_mode
        self.erb_trim_mode = '-'

        self.default_format = Mime::HTML

        cattr_accessor :erb_implementation
        self.erb_implementation = Erubis

        ENCODING_TAG = Regexp.new("\A(<%#{ENCODING_FLAG}-?%>)[ \t]*")

        def compile(template)
          erb = template.source.gsub(ENCODING_TAG, '')
          result = self.class.erb_implementation.new(
            erb,
            :trim => (self.class.erb_trim_mode == "-")
          ).src

          result = "#{$2}\n#{result}" if $2
          result
        end
      end
    end
  end
end
