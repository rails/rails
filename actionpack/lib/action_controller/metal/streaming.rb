require 'active_support/core_ext/file/path'
require 'rack/chunked'

module ActionController #:nodoc:
  # Methods for sending streaming templates back to the client.
  module Streaming
    extend ActiveSupport::Concern

    include AbstractController::Rendering
    attr_internal :stream

    module ClassMethods
      # Render streaming templates. It accepts :only, :except, :if and :unless as options
      # to specify when to stream, as in ActionController filters.
      def stream(options={})
        if defined?(Fiber)
          before_filter :_stream_filter, options
        else
          raise "You cannot use streaming if Fiber is not available."
        end
      end
    end

    protected

    # Mark following render calls as streaming.
    def _stream_filter #:nodoc:
      self.stream = true
    end

    # Consider the stream option when normalazing options.
    def _normalize_options(options) #:nodoc:
      super
      options[:stream] = self.stream unless options.key?(:stream)
    end

    # Set proper cache control and transfer encoding when streaming
    def _process_options(options) #:nodoc:
      super
      if options[:stream]
        headers["Cache-Control"] ||= "no-cache"
        headers["Transfer-Encoding"] = "chunked"
        headers.delete("Content-Length")
      end
    end

    # Call render_to_body if we are streaming instead of usual +render+.
    def _render_template(options) #:nodoc:
      if options.delete(:stream)
        Rack::Chunked::Body.new view_context.render_body(options)
      else
        super
      end
    end
  end
end
      