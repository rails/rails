# frozen_string_literal: true

require "strscan"
require "active_support/core_ext/erb/util"

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

        # Strip trailing newlines from rendered output
        class_attribute :strip_trailing_newlines, default: false

        ENCODING_TAG = Regexp.new("\\A(<%#{ENCODING_FLAG}-?%>)[ \\t]*")

        LocationParsingError = Class.new(StandardError) # :nodoc:

        def self.call(template, source)
          new.call(template, source)
        end

        def supports_streaming?
          true
        end

        def handles_encoding?
          true
        end

        # Translate an error location returned by ErrorHighlight to the correct
        # source location inside the template.
        def translate_location(spot, _backtrace_location, source)
          compiled = spot[:script_lines]
          highlight = compiled[spot[:first_lineno] - 1]&.byteslice((spot[:first_column] - 1)...spot[:last_column])
          return nil if highlight.blank?

          source_lines = source.lines
          lineno_delta = find_lineno_offset(compiled, source_lines, highlight, spot[:first_lineno])

          tokens = ::ERB::Util.tokenize(source_lines[spot[:first_lineno] - lineno_delta - 1])
          column_delta = find_offset(spot[:snippet], tokens, spot[:first_column])

          spot[:first_lineno] -= lineno_delta
          spot[:last_lineno] -= lineno_delta
          spot[:first_column] -= column_delta
          spot[:last_column] -= column_delta
          spot[:script_lines] = source_lines

          spot
        rescue NotImplementedError, LocationParsingError
          nil
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

          # Strip trailing newlines from the template if enabled
          erb.chomp! if strip_trailing_newlines

          options = {
            escape: (self.class.escape_ignore_list.include? template.type),
            trim: (self.class.erb_trim_mode == "-")
          }

          if ActionView::Base.annotate_rendered_view_with_filenames && template.format == :html
            options[:preamble] = "@output_buffer.safe_append='<!-- BEGIN #{template.short_identifier} -->';"
            options[:postamble] = "@output_buffer.safe_append='<!-- END #{template.short_identifier} -->';@output_buffer"
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

        # Return the offset between the error lineno and the source lineno.
        # Searches in reverse from the backtrace lineno so we have a better
        # chance of finding the correct line
        #
        # The compiled template is likely to be longer than the source.
        # Use the difference between the compiled and source sizes to
        # determine the earliest line that could contain the highlight.
        def find_lineno_offset(compiled, source_lines, highlight, error_lineno)
          first_index = error_lineno - 1 - compiled.size + source_lines.size
          first_index = 0 if first_index < 0

          last_index = error_lineno - 1
          last_index = source_lines.size - 1 if last_index >= source_lines.size

          last_index.downto(first_index) do |line_index|
            next unless source_lines[line_index].include?(highlight)
            return error_lineno - 1 - line_index
          end

          raise LocationParsingError, "Couldn't find code snippet"
        end

        # Find which token in the source template spans the byte range that
        # contains the error_column, then return the offset compared to the
        # original source template.
        #
        # Iterate consecutive pairs of CODE or TEXT tokens, requiring
        # a match of the first token before matching either token.
        #
        # For example, if we want to find tokens A, B, C, we do the following:
        # 1. Find a match for A: test error_column or advance scanner.
        # 2. Find a match for B or A:
        #   a. If B: start over with next token set (B, C).
        #   b. If A: test error_column or advance scanner.
        #   c. Otherwise: Advance 1 byte
        #
        # Prioritize matching the next token over the current token once
        # a match for the current token has been found. This is to prevent
        # the current token from looping past the next token if they both
        # match (i.e. if the current token is a single space character).
        def find_offset(compiled, source_tokens, error_column)
          compiled = StringScanner.new(compiled)
          offset_source_tokens(source_tokens).each_cons(2) do |(name, str, offset), (_, next_str, _)|
            matched_str = false

            until compiled.eos?
              if matched_str && next_str && compiled.match?(next_str)
                break
              elsif compiled.match?(str)
                matched_str = true

                if name == :CODE && compiled.pos <= error_column && compiled.pos + str.bytesize >= error_column
                  return compiled.pos - offset
                end

                compiled.pos += str.bytesize
              else
                compiled.pos += 1
              end
            end
          end

          raise LocationParsingError, "Couldn't find code snippet"
        end

        def offset_source_tokens(source_tokens)
          source_offset = 0
          with_offset = source_tokens.filter_map do |name, str|
            result = [:CODE, str, source_offset] if name == :CODE || name == :PLAIN
            result = [:TEXT, str, source_offset] if name == :TEXT
            source_offset += str.bytesize
            result
          end
          with_offset << [:EOS, nil, source_offset]
        end
      end
    end
  end
end
