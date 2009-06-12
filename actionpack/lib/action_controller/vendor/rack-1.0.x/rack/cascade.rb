module Rack
  # Rack::Cascade tries an request on several apps, and returns the
  # first response that is not 404 (or in a list of configurable
  # status codes).

  class Cascade
    NotFound = [404, {}, []]

    attr_reader :apps

    def initialize(apps, catch=404)
      @apps = []; @has_app = {}
      apps.each { |app| add app }

      @catch = {}
      [*catch].each { |status| @catch[status] = true }
    end

    def call(env)
      result = NotFound

      @apps.each do |app|
        result = app.call(env)
        break unless @catch.include?(result[0].to_i)
      end

      result
    end

    def add app
      @has_app[app] = true
      @apps << app
    end

    def include? app
      @has_app.include? app
    end

    alias_method :<<, :add
  end
end
