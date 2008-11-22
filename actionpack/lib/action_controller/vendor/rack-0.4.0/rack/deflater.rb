require "zlib"
require "stringio"

module Rack

class Deflater
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    request = Request.new(env)

    encoding = Utils.select_best_encoding(%w(gzip deflate identity), request.accept_encoding)

    case encoding
    when "gzip"
      mtime = headers["Last-Modified"] || Time.now
      [status, headers.merge("Content-Encoding" => "gzip"), self.class.gzip(body, mtime)]
    when "deflate"
      [status, headers.merge("Content-Encoding" => "deflate"), self.class.deflate(body)]
    when "identity"
      [status, headers, body]
    when nil
      message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
      [406, {"Content-Type" => "text/plain"}, message]
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
