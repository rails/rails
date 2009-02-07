require "zlib"
require "stringio"
require "time"  # for Time.httpdate
require 'rack/utils'

module Rack
  class Deflater
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)

      # Skip compressing empty entity body responses and responses with
      # no-transform set.
      if Utils::STATUS_WITH_NO_ENTITY_BODY.include?(status) ||
          headers['Cache-Control'].to_s =~ /\bno-transform\b/
        return [status, headers, body]
      end

      request = Request.new(env)

      encoding = Utils.select_best_encoding(%w(gzip deflate identity),
                                            request.accept_encoding)

      # Set the Vary HTTP header.
      vary = headers["Vary"].to_s.split(",").map { |v| v.strip }
      unless vary.include?("*") || vary.include?("Accept-Encoding")
        headers["Vary"] = vary.push("Accept-Encoding").join(",")
      end

      case encoding
      when "gzip"
        mtime = headers.key?("Last-Modified") ?
          Time.httpdate(headers["Last-Modified"]) : Time.now
        body = self.class.gzip(body, mtime)
        size = body.respond_to?(:bytesize) ? body.bytesize : body.size
        headers = headers.merge("Content-Encoding" => "gzip", "Content-Length" => size.to_s)
        [status, headers, [body]]
      when "deflate"
        body = self.class.deflate(body)
        size = body.respond_to?(:bytesize) ? body.bytesize : body.size
        headers = headers.merge("Content-Encoding" => "deflate", "Content-Length" => size.to_s)
        [status, headers, [body]]
      when "identity"
        [status, headers, body]
      when nil
        message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
        [406, {"Content-Type" => "text/plain", "Content-Length" => message.length.to_s}, [message]]
      end
    end

    def self.gzip(body, mtime)
      io = StringIO.new
      gzip = Zlib::GzipWriter.new(io)
      gzip.mtime = mtime

      # TODO: Add streaming
      body.each { |part| gzip << part }

      gzip.close
      return io.string
    end

    DEFLATE_ARGS = [
      Zlib::DEFAULT_COMPRESSION,
      # drop the zlib header which causes both Safari and IE to choke
     -Zlib::MAX_WBITS,
      Zlib::DEF_MEM_LEVEL,
      Zlib::DEFAULT_STRATEGY
    ]

    # Loosely based on Mongrel's Deflate handler
    def self.deflate(body)
      deflater = Zlib::Deflate.new(*DEFLATE_ARGS)

      # TODO: Add streaming
      body.each { |part| deflater << part }

      return deflater.finish
    end
  end
end
