# frozen_string_literal: true

# :markup: markdown
# :enddoc:

module Rails
  module Rackup
    begin
      require "rackup/server"
      Server = ::Rackup::Server
    rescue LoadError
      require "rack/server"
      Server = ::Rack::Server
    end
  end
end
