require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/string/output_safety'
require "action_view/template"
require 'erubis'

module ActionView
  class OutputBuffer < ActiveSupport::SafeBuffer
    def initialize(*)
      super
      encode! if encoding_aware?
    end

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

        ENCODING_TAG = Regexp.new("\\A(<%#{ENCODING_FLAG}-?%>)[ \\t]*")

        def self.handles_encoding?
          true
        end

        def compile(template)
          if template.source.encoding_aware?
            # First, convert to BINARY, so in case the encoding is
            # wrong, we can still find an encoding tag
            # (<%# encoding %>) inside the String using a regular
            # expression
            template_source = template.source.dup.force_encoding("BINARY")

            erb = template_source.gsub(ENCODING_TAG, '')
            encoding = $2

            erb.force_encoding valid_encoding(template.source.dup, encoding)

            # Always make sure we return a String in the default_internal
            erb.encode!
          else
            erb = template.source.dup
          end

          self.class.erb_implementation.new(
            erb,
            :trim => (self.class.erb_trim_mode == "-")
          ).src
        end

      private
        def valid_encoding(string, encoding)
          # If a magic encoding comment was found, tag the
          # String with this encoding. This is for a case
          # where the original String was assumed to be,
          # for instance, UTF-8, but a magic comment
          # proved otherwise
          string.force_encoding(encoding) if encoding

          # If the String is valid, return the encoding we found
          return string.encoding if string.valid_encoding?

          # Otherwise, raise an exception
          raise WrongEncodingError.new(string, string.encoding)
        end
      end
    end
  end
end
