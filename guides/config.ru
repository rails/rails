# frozen_string_literal: true

require "rack/static"

class App
  def call(env)
    [404, { "content-type" => "text/plain" }, ["Page not found"]]
  end
end

use Rack::Static, urls: [""], root: "output", index: "index.html"
run App.new
