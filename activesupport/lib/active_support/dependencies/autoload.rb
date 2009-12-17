require "active_support/inflector/methods"

module ActiveSupport
  module Autoload
    @@autoloads = {}
    @@under_path = nil
    @@at_path = nil
    @@autoload_defer = false

    def autoload(const_name, path = @@at_path)
      full = [self.name, @@under_path, const_name.to_s, path].compact.join("::")
      location = path || Inflector.underscore(full)

      unless @@autoload_defer
        @@autoloads[const_name] = location
      end
      super const_name, location
    end

    def autoload_under(path)
      @@under_path, old_path = path, @@under_path
      yield
    ensure
      @@under_path = old_path
    end

    def autoload_at(path)
      @@at_path, old_path = path, @@at_path
      yield
    ensure
      @@at_path = old_path
    end

    def deferrable
      old_defer, @@autoload_defer = @@autoload_defer, true
      yield
    ensure
      @@autoload_defer = old_defer
    end

    def self.eager_autoload!
      @@autoloads.values.each { |file| require file }
    end

    def autoloads
      @@autoloads
    end
  end
end
