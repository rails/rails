# frozen_string_literal: true

module ActionView
  class Template
    module Handlers
      class ERB
        autoload :Erubi, "action_view/template/handlers/erb/erubi"

        # Specify trim mode for the ERB compiler. Defaults to '-'.
        # See ERB documentation for suitable values.
        class_attribute :erb_trim_mode, default: "-"

        # Default implementation used.
        class_attribute :erb_implementation, default: Erubi

        # Do not escape templates of these mime types.
        class_attribute :escape_ignore_list, default: ["text/plain"]

        ENCODING_TAG = Regexp.new("\\A(<%#{ENCODING_FLAG}-?%>)[ \\t]*")

        def self.call(template, source)
          new.call(template, source)
        end

        def supports_streaming?
          true
        end

        def handles_encoding?
          true
        end

        def call(template, source)
          # First, convert to BINARY, so in case the encoding is
          # wrong, we can still find an encoding tag
          # (<%# encoding %>) inside the String using a regular
          # expression
          template_source = source.b

          erb = template_source.gsub(ENCODING_TAG, "")
          encoding = $2

          erb.force_encoding valid_encoding(source.dup, encoding)

          # Always make sure we return a String in the default_internal
          erb.encode!

          options = {
            escape: (self.class.escape_ignore_list.include? template.type),
            trim: (self.class.erb_trim_mode == "-")
          }

          if ActionView::Base.annotate_rendered_view_with_filenames && template.format == :html
            options[:preamble] = "@output_buffer.safe_append='<!-- BEGIN #{template.short_identifier} -->';"
            options[:postamble] = "@output_buffer.safe_append='<!-- END #{template.short_identifier} -->';@output_buffer.to_s"
          end

          self.class.erb_implementation.new(erb, options).src
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
