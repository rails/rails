require 'action_dispatch/http/mime_type'
require 'active_support/core_ext/class/attribute'
require 'erubis'

module ActionView
  class Template
    module Handlers
      class Erubis < ::Erubis::Eruby
        def add_preamble(src)
          src << "@output_buffer = output_buffer || ActionView::OutputBuffer.new;"
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

        def add_expr_escaped(src, code)
          if code =~ BLOCK_EXPR
            src << "@output_buffer.safe_append= " << code
          else
            src << "@output_buffer.safe_concat((" << code << ").to_s);"
          end
        end

        def add_postamble(src)
          src << '@output_buffer.to_s'
        end
      end

      class ERB
        # Specify trim mode for the ERB compiler. Defaults to '-'.
        # See ERB documentation for suitable values.
        class_attribute :erb_trim_mode
        self.erb_trim_mode = '-'

        # Default implementation used.
        class_attribute :erb_implementation
        self.erb_implementation = Erubis

        # Do not escape templates of these mime types.
        class_attribute :escape_whitelist
        self.escape_whitelist = ["text/plain"]

        ENCODING_TAG = Regexp.new("\\A(<%#{ENCODING_FLAG}-?%>)[ \\t]*")

        def self.call(template)
          new.call(template)
        end

        def supports_streaming?
          true
        end

        def handles_encoding?
          true
        end

        def call(template)
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
            :escape => (self.class.escape_whitelist.include? template.mime_type),
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
