# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Http
    class ContentDisposition # :nodoc:
      # HTTP token characters (RFC 7230 §3.2.6). Stopping at the first non-token
      # character prevents disposition values like "attachment\r\nX-Evil: 1" from
      # injecting additional response headers via Content-Disposition.
      DISPOSITION_TOKEN = /\A[!\#$%&'*+\-.^_`|~0-9A-Za-z]+/

      def self.format(disposition:, filename:)
        new(disposition: disposition, filename: filename).to_s
      end

      attr_reader :disposition, :filename

      def initialize(disposition:, filename:)
        @disposition = sanitize_disposition(disposition)
        @filename = filename
      end

      TRADITIONAL_ESCAPED_CHAR = /[^ A-Za-z0-9!\#$+.^_`|~-]/

      def ascii_filename
        'filename="' + percent_escape(I18n.transliterate(filename), TRADITIONAL_ESCAPED_CHAR) + '"'
      end

      RFC_5987_ESCAPED_CHAR = /[^A-Za-z0-9!\#$&+.^_`|~-]/

      def utf8_filename
        "filename*=UTF-8''" + percent_escape(filename, RFC_5987_ESCAPED_CHAR)
      end

      def to_s
        if filename
          "#{disposition}; #{ascii_filename}; #{utf8_filename}"
        else
          "#{disposition}"
        end
      end

      private
        def sanitize_disposition(disposition)
          disposition.to_s[DISPOSITION_TOKEN].presence || "attachment"
        end

        def percent_escape(string, pattern)
          string.gsub(pattern) do |char|
            char.bytes.map { |byte| "%%%02X" % byte }.join
          end
        end
    end
  end
end
