module Rack
  # Rack::Cascade tries an request on several apps, and returns the
  # first response that is not 404 (or in a list of configurable
  # status codes).

  class Cascade
    attr_reader :apps

    def initialize(apps, catch=404)
      @apps = apps
      @catch = [*catch]
    end

    def call(env)
      status = headers = body = nil
      raise ArgumentError, "empty cascade"  if @apps.empty?
      @apps.each { |app|
        begin
          status, headers, body = app.call(env)
          break  unless @catch.include?(status.to_i)
        end
      }
      [status, headers, body]
    end

    def add app
      @apps << app
    end

    def include? app
      @apps.include? app
    end

    alias_method :<<, :add
  end
end
