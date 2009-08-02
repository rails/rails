require 'active_support/core_ext/string/bytesize'

module ActionController #:nodoc:
  # Methods for sending arbitrary data and for streaming files to the browser,
  # instead of rendering.
  module Streaming
    DEFAULT_SEND_FILE_OPTIONS = {
      :type         => 'application/octet-stream'.freeze,
      :disposition  => 'attachment'.freeze,
      :stream       => true,
      :buffer_size  => 4096,
      :x_sendfile   => false
    }.freeze

    X_SENDFILE_HEADER = 'X-Sendfile'.freeze

    protected
      # Sends the file, by default streaming it 4096 bytes at a time. This way the
      # whole file doesn't need to be read into memory at once. This makes it
      # feasible to send even large files. You can optionally turn off streaming
      # and send the whole file at once.
      #
      # Be careful to sanitize the path parameter if it is coming from a web
      # page. <tt>send_file(params[:path])</tt> allows a malicious user to
      # download any file on your server.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      #   Defaults to <tt>File.basename(path)</tt>.
      # * <tt>:type</tt> - specifies an HTTP content type. Defaults to 'application/octet-stream'. You can specify
      #   either a string or a symbol for a registered type register with <tt>Mime::Type.register</tt>, for example :json
      # * <tt>:length</tt> - used to manually override the length (in bytes) of the content that
      #   is going to be sent to the client. Defaults to <tt>File.size(path)</tt>.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:stream</tt> - whether to send the file to the user agent as it is read (+true+)
      #   or to read the entire file before sending (+false+). Defaults to +true+.
      # * <tt>:buffer_size</tt> - specifies size (in bytes) of the buffer used to stream the file.
      #   Defaults to 4096.
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to '200 OK'.
      # * <tt>:url_based_filename</tt> - set to +true+ if you want the browser guess the filename from
      #   the URL, which is necessary for i18n filenames on certain browsers
      #   (setting <tt>:filename</tt> overrides this option).
      # * <tt>:x_sendfile</tt> - uses X-Sendfile to send the file when set to +true+. This is currently
      #   only available with Lighttpd/Apache2 and specific modules installed and activated. Since this
      #   uses the web server to send the file, this may lower memory consumption on your server and
      #   it will not block your application for further requests.
      #   See http://blog.lighttpd.net/articles/2006/07/02/x-sendfile and
      #   http://tn123.ath.cx/mod_xsendfile/ for details. Defaults to +false+.
      #
      # The default Content-Type and Content-Disposition headers are
      # set to download arbitrary binary files in as many browsers as
      # possible.  IE versions 4, 5, 5.5, and 6 are all known to have
      # a variety of quirks (especially when downloading over SSL).
      #
      # Simple download:
      #
      #   send_file '/path/to.zip'
      #
      # Show a JPEG in the browser:
      #
      #   send_file '/path/to.jpeg', :type => 'image/jpeg', :disposition => 'inline'
      #
      # Show a 404 page in the browser:
      #
      #   send_file '/path/to/404.html', :type => 'text/html; charset=utf-8', :status => 404
      #
      # Read about the other Content-* HTTP headers if you'd like to
      # provide the user with more information (such as Content-Description) in
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.11.
      #
      # Also be aware that the document may be cached by proxies and browsers.
      # The Pragma and Cache-Control headers declare how the file may be cached
      # by intermediaries.  They default to require clients to validate with
      # the server before releasing cached responses.  See
      # http://www.mnot.net/cache_docs/ for an overview of web caching and
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.9
      # for the Cache-Control header spec.
      def send_file(path, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{path}" unless File.file?(path) and File.readable?(path)

        options[:length]   ||= File.size(path)
        options[:filename] ||= File.basename(path) unless options[:url_based_filename]
        send_file_headers! options

        @performed_render = false

        if options[:x_sendfile]
          logger.info "Sending #{X_SENDFILE_HEADER} header #{path}" if logger
          head options[:status], X_SENDFILE_HEADER => path
        else
          if options[:stream]
            render :status => options[:status], :text => Proc.new { |response, output|
              logger.info "Streaming file #{path}" unless logger.nil?
              len = options[:buffer_size] || 4096
              File.open(path, 'rb') do |file|
                while buf = file.read(len)
                  output.write(buf)
                end
              end
            }
          else
            logger.info "Sending file #{path}" unless logger.nil?
            File.open(path, 'rb') { |file| render :status => options[:status], :text => file.read }
          end
        end
      end

      # Sends the given binary data to the browser. This method is similar to
      # <tt>render :text => data</tt>, but also allows you to specify whether
      # the browser should display the response as a file attachment (i.e. in a
      # download dialog) or as inline data. You may also set the content type,
      # the apparent file name, and other things.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      # * <tt>:type</tt> - specifies an HTTP content type. Defaults to 'application/octet-stream'. You can specify
      #   either a string or a symbol for a registered type register with <tt>Mime::Type.register</tt>, for example :json
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to '200 OK'.
      #
      # Generic data download:
      #
      #   send_data buffer
      #
      # Download a dynamically-generated tarball:
      #
      #   send_data generate_tgz('dir'), :filename => 'dir.tgz'
      #
      # Display an image Active Record in the browser:
      #
      #   send_data image.data, :type => image.content_type, :disposition => 'inline'
      #
      # See +send_file+ for more information on HTTP Content-* headers and caching.
      #
      # <b>Tip:</b> if you want to stream large amounts of on-the-fly generated
      # data to the browser, then use <tt>render :text => proc { ... }</tt>
      # instead. See ActionController::Base#render for more information.
      def send_data(data, options = {}) #:doc:
        logger.info "Sending data #{options[:filename]}" if logger
        send_file_headers! options.merge(:length => data.bytesize)
        @performed_render = false
        render :status => options[:status], :text => data
      end

    private
      def send_file_headers!(options)
        options.update(DEFAULT_SEND_FILE_OPTIONS.merge(options))
        [:length, :type, :disposition].each do |arg|
          raise ArgumentError, ":#{arg} option required" if options[arg].nil?
        end

        disposition = options[:disposition].dup || 'attachment'

        disposition <<= %(; filename="#{options[:filename]}") if options[:filename]

        content_type = options[:type]
        if content_type.is_a?(Symbol)
          raise ArgumentError, "Unknown MIME type #{options[:type]}" unless Mime::EXTENSION_LOOKUP.has_key?(content_type.to_s)
          content_type = Mime::Type.lookup_by_extension(content_type.to_s)
        end
        content_type = content_type.to_s.strip # fixes a problem with extra '\r' with some browsers

        headers.merge!(
          'Content-Length'            => options[:length].to_s,
          'Content-Type'              => content_type,
          'Content-Disposition'       => disposition,
          'Content-Transfer-Encoding' => 'binary'
        )

        # Fix a problem with IE 6.0 on opening downloaded files:
        # If Cache-Control: no-cache is set (which Rails does by default),
        # IE removes the file it just downloaded from its cache immediately
        # after it displays the "open/save" dialog, which means that if you
        # hit "open" the file isn't there anymore when the application that
        # is called for handling the download is run, so let's workaround that
        headers['Cache-Control'] = 'private' if headers['Cache-Control'] == 'no-cache'
      end
  end
end
