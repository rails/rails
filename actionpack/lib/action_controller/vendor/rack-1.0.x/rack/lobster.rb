require 'zlib'

require 'rack/request'
require 'rack/response'

module Rack
  # Paste has a Pony, Rack has a Lobster!
  class Lobster
    LobsterString = Zlib::Inflate.inflate("eJx9kEEOwyAMBO99xd7MAcytUhPlJyj2
    P6jy9i4k9EQyGAnBarEXeCBqSkntNXsi/ZCvC48zGQoZKikGrFMZvgS5ZHd+aGWVuWwhVF0
    t1drVmiR42HcWNz5w3QanT+2gIvTVCiE1lm1Y0eU4JGmIIbaKwextKn8rvW+p5PIwFl8ZWJ
    I8jyiTlhTcYXkekJAzTyYN6E08A+dk8voBkAVTJQ==".delete("\n ").unpack("m*")[0])

    LambdaLobster = lambda { |env|
      if env["QUERY_STRING"].include?("flip")
        lobster = LobsterString.split("\n").
          map { |line| line.ljust(42).reverse }.
          join("\n")
        href = "?"
      else
        lobster = LobsterString
        href = "?flip"
      end

      content = ["<title>Lobstericious!</title>",
                 "<pre>", lobster, "</pre>",
                 "<a href='#{href}'>flip!</a>"]
      length = content.inject(0) { |a,e| a+e.size }.to_s
      [200, {"Content-Type" => "text/html", "Content-Length" => length}, content]
    }

    def call(env)
      req = Request.new(env)
      if req.GET["flip"] == "left"
        lobster = LobsterString.split("\n").
          map { |line| line.ljust(42).reverse }.
          join("\n")
        href = "?flip=right"
      elsif req.GET["flip"] == "crash"
        raise "Lobster crashed"
      else
        lobster = LobsterString
        href = "?flip=left"
      end

      res = Response.new
      res.write "<title>Lobstericious!</title>"
      res.write "<pre>"
      res.write lobster
      res.write "</pre>"
      res.write "<p><a href='#{href}'>flip!</a></p>"
      res.write "<p><a href='?flip=crash'>crash!</a></p>"
      res.finish
    end

  end
end

if $0 == __FILE__
  require 'rack'
  require 'rack/showexceptions'
  Rack::Handler::WEBrick.run \
    Rack::ShowExceptions.new(Rack::Lint.new(Rack::Lobster.new)),
    :Port => 9292
end
