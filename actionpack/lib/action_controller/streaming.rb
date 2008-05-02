module ActionController #:nodoc:
  # Methods for sending files and streams to the browser instead of rendering.
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
      # Sends the file by streaming it 4096 bytes at a time. This way the
      # whole file doesn't need to be read into memory at once.  This makes
      # it feasible to send even large files.
      #
      # Be careful to sanitize the path parameter if it coming from a web
      # page. <tt>send_file(params[:path])</tt> allows a malicious user to
      # download any file on your server.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      #   Defaults to <tt>File.basename(path)</tt>.
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   Defaults to 'application/octet-stream'.
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

      # Send binary data to the user as a file download.  May set content type, apparent file name,
      # and specify whether to show data inline or download as an attachment.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   Defaults to 'application/octet-stream'.
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
      def send_data(data, options = {}) #:doc:
        logger.info "Sending data #{options[:filename]}" if logger
        send_file_headers! options.merge(:length => data.size)
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

        headers.update(
          'Content-Length'            => options[:length],
          'Content-Type'              => options[:type].to_s.strip,  # fixes a problem with extra '\r' with some browsers
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
