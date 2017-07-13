class ActiveStorage::Download
  # Sending .ai files as application/postscript to Safari opens them in a blank, grey screen.
  # Downloading .ai as application/postscript files in Safari appends .ps to the extension.
  # Sending HTML, SVG, XML and SWF files as binary closes XSS vulnerabilities.
  # Sending JS files as binary avoids InvalidCrossOriginRequest without compromising security.
  CONTENT_TYPES_TO_RENDER_AS_BINARY = %w(
    text/html
    text/javascript
    image/svg+xml
    application/postscript
    application/x-shockwave-flash
    text/xml
    application/xml
    application/xhtml+xml
  )

  BINARY_CONTENT_TYPE = "application/octet-stream"

  def initialize(stored_file)
    @stored_file = stored_file
  end

  def headers(force_attachment: false)
    {
      x_accel_redirect:    "/reproxy",
      x_reproxy_url:       reproxy_url,
      content_type:        content_type,
      content_disposition: content_disposition(force_attachment),
      x_frame_options:     "SAMEORIGIN"
    }
  end

  private
    def reproxy_url
      @stored_file.depot_location.paths.first
    end

    def content_type
      if @stored_file.content_type.in? CONTENT_TYPES_TO_RENDER_AS_BINARY
        BINARY_CONTENT_TYPE
      else
        @stored_file.content_type
      end
    end

    def content_disposition(force_attachment = false)
      if force_attachment || content_type == BINARY_CONTENT_TYPE
        "attachment; #{escaped_filename}"
      else
        "inline; #{escaped_filename}"
      end
    end

    # RFC2231 encoding for UTF-8 filenames, with an ASCII fallback
    # first for unsupported browsers (IE < 9, perhaps others?).
    # http://greenbytes.de/tech/tc2231/#encoding-2231-fb
    def escaped_filename
      filename = @stored_file.filename.sanitized
      ascii_filename = encode_ascii_filename(filename)
      utf8_filename = encode_utf8_filename(filename)
      "#{ascii_filename}; #{utf8_filename}"
    end

    TRADITIONAL_PARAMETER_ESCAPED_CHAR = /[^ A-Za-z0-9!#$+.^_`|~-]/

    def encode_ascii_filename(filename)
      # There is no reliable way to escape special or non-Latin characters
      # in a traditionally quoted Content-Disposition filename parameter.
      # Settle for transliterating to ASCII, then percent-escaping special
      # characters, excluding spaces.
      filename = I18n.transliterate(filename)
      filename = percent_escape(filename, TRADITIONAL_PARAMETER_ESCAPED_CHAR)
      %(filename="#{filename}")
    end

    RFC5987_PARAMETER_ESCAPED_CHAR = /[^A-Za-z0-9!#$&+.^_`|~-]/

    def encode_utf8_filename(filename)
      # RFC2231 filename parameters can simply be percent-escaped according
      # to RFC5987.
      filename = percent_escape(filename, RFC5987_PARAMETER_ESCAPED_CHAR)
      %(filename*=UTF-8''#{filename})
    end

    def percent_escape(string, pattern)
      string.gsub(pattern) do |char|
        char.bytes.map { |byte| "%%%02X" % byte }.join("")
      end
    end
end
