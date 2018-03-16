# frozen_string_literal: true

require "action_controller/metal/exceptions"

module ActionController #:nodoc:
  # Methods for sending arbitrary data and for streaming files to the browser,
  # instead of rendering.
  module DataStreaming
    extend ActiveSupport::Concern

    include ActionController::Rendering

    DEFAULT_SEND_FILE_TYPE        = "application/octet-stream" #:nodoc:
    DEFAULT_SEND_FILE_DISPOSITION = "attachment" #:nodoc:

    private
      # Sends the file. This uses a server-appropriate method (such as X-Sendfile)
      # via the Rack::Sendfile middleware. The header to use is set via
      # +config.action_dispatch.x_sendfile_header+.
      # Your server can also configure this for you by setting the X-Sendfile-Type header.
      #
      # Be careful to sanitize the path parameter if it is coming from a web
      # page. <tt>send_file(params[:path])</tt> allows a malicious user to
      # download any file on your server.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      #   Defaults to <tt>File.basename(path)</tt>.
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   You can specify either a string or a symbol for a registered type with <tt>Mime::Type.register</tt>, for example :json.
      #   If omitted, the type will be inferred from the file extension specified in <tt>:filename</tt>.
      #   If no content type is registered for the extension, the default type 'application/octet-stream' will be used.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to 200.
      # * <tt>:url_based_filename</tt> - set to +true+ if you want the browser to guess the filename from
      #   the URL, which is necessary for i18n filenames on certain browsers
      #   (setting <tt>:filename</tt> overrides this option).
      #
      # The default Content-Type and Content-Disposition headers are
      # set to download arbitrary binary files in as many browsers as
      # possible. IE versions 4, 5, 5.5, and 6 are all known to have
      # a variety of quirks (especially when downloading over SSL).
      #
      # Simple download:
      #
      #   send_file '/path/to.zip'
      #
      # Show a JPEG in the browser:
      #
      #   send_file '/path/to.jpeg', type: 'image/jpeg', disposition: 'inline'
      #
      # Show a 404 page in the browser:
      #
      #   send_file '/path/to/404.html', type: 'text/html; charset=utf-8', status: 404
      #
      # Read about the other Content-* HTTP headers if you'd like to
      # provide the user with more information (such as Content-Description) in
      # https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.11.
      #
      # Also be aware that the document may be cached by proxies and browsers.
      # The Pragma and Cache-Control headers declare how the file may be cached
      # by intermediaries. They default to require clients to validate with
      # the server before releasing cached responses. See
      # https://www.mnot.net/cache_docs/ for an overview of web caching and
      # https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.9
      # for the Cache-Control header spec.
      def send_file(path, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{path}" unless File.file?(path) && File.readable?(path)

        options[:filename] ||= File.basename(path) unless options[:url_based_filename]
        send_file_headers! options

        self.status = options[:status] || 200
        self.content_type = options[:content_type] if options.key?(:content_type)
        response.send_file path
      end

      # Sends the given binary data to the browser. This method is similar to
      # <tt>render plain: data</tt>, but also allows you to specify whether
      # the browser should display the response as a file attachment (i.e. in a
      # download dialog) or as inline data. You may also set the content type,
      # the file name, and other things.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      # * <tt>:type</tt> - specifies an HTTP content type. Defaults to 'application/octet-stream'.
      #   You can specify either a string or a symbol for a registered type with <tt>Mime::Type.register</tt>, for example :json.
      #   If omitted, type will be inferred from the file extension specified in <tt>:filename</tt>.
      #   If no content type is registered for the extension, the default type 'application/octet-stream' will be used.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to 200.
      #
      # Generic data download:
      #
      #   send_data buffer
      #
      # Download a dynamically-generated tarball:
      #
      #   send_data generate_tgz('dir'), filename: 'dir.tgz'
      #
      # Display an image Active Record in the browser:
      #
      #   send_data image.data, type: image.content_type, disposition: 'inline'
      #
      # See +send_file+ for more information on HTTP Content-* headers and caching.
      def send_data(data, options = {}) #:doc:
        send_file_headers! options
        render options.slice(:status, :content_type).merge(body: data)
      end

      def send_file_headers!(options)
        type_provided = options.has_key?(:type)

        content_type = options.fetch(:type, DEFAULT_SEND_FILE_TYPE)
        self.content_type = content_type
        response.sending_file = true

        raise ArgumentError, ":type option required" if content_type.nil?

        if content_type.is_a?(Symbol)
          extension = Mime[content_type]
          raise ArgumentError, "Unknown MIME type #{options[:type]}" unless extension
          self.content_type = extension
        else
          if !type_provided && options[:filename]
            # If type wasn't provided, try guessing from file extension.
            content_type = Mime::Type.lookup_by_extension(File.extname(options[:filename]).downcase.delete(".")) || content_type
          end
          self.content_type = content_type
        end

        disposition = options.fetch(:disposition, DEFAULT_SEND_FILE_DISPOSITION)
        unless disposition.nil?
          disposition  = disposition.to_s
          disposition += %(; filename="#{options[:filename]}") if options[:filename]
          headers["Content-Disposition"] = disposition
        end

        headers["Content-Transfer-Encoding"] = "binary"

        # Fix a problem with IE 6.0 on opening downloaded files:
        # If Cache-Control: no-cache is set (which Rails does by default),
        # IE removes the file it just downloaded from its cache immediately
        # after it displays the "open/save" dialog, which means that if you
        # hit "open" the file isn't there anymore when the application that
        # is called for handling the download is run, so let's workaround that
        response.cache_control[:public] ||= false
      end
  end
end
