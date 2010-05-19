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

        def self.accepts_binary?
          true
        end

        def compile(template)
          if template.source.encoding_aware?
            # Even though Rails has given us a String tagged with the
            # default_internal encoding (likely UTF-8), it is possible
            # that the String is actually encoded using a different
            # encoding, specified via an ERB magic comment. If the
            # String is not actually UTF-8, the regular expression
            # engine will (correctly) raise an exception. For now,
            # we'll reset the String to BINARY so we can run regular
            # expressions against it
            template_source = template.source.dup.force_encoding("BINARY")

            # Erubis does not have direct support for encodings.
            # As a result, we will extract the ERB-style magic
            # comment, give the String to Erubis as BINARY data,
            # and then tag the resulting String with the extracted
            # encoding later
            erb = template_source.gsub(ENCODING_TAG, '')
            encoding = $2

            if !encoding && (template.source.encoding == Encoding::BINARY)
              raise WrongEncodingError.new(template_source, Encoding.default_external)
            end
          else
            erb = template.source.dup
          end

          result = self.class.erb_implementation.new(
            erb,
            :trim => (self.class.erb_trim_mode == "-")
          ).src

          # If an encoding tag was found, tag the String
          # we're returning with that encoding. Otherwise,
          # return a BINARY String, which is what ERB
          # returns. Note that if a magic comment was
          # not specified, we will return the data to
          # Rails as BINARY, which will then use its
          # own encoding logic to create a UTF-8 String.
          result = "\n#{result}".force_encoding(encoding).encode if encoding
          result
        end
      end
    end
  end
end
