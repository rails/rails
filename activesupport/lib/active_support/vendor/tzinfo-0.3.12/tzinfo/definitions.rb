require "tzinfo/data_timezone_info"
require "tzinfo/linked_timezone_info"
require "tzinfo/timezone_definition"

module TZInfo
  module Definitions
    def self.load_all!
      return true if @loaded
      @loaded = true

      defns = Marshal.load(File.read(File.expand_path("../definitions.dump", __FILE__)))

      defns.each do |defn|
        tz_mod = defn.instance_variable_get(:@identifier).split("/").reduce(TZInfo::Definitions) { |mod, name|
          if mod.const_defined?(name)
            mod.const_get(name)
          else
            mod.const_set(name, Module.new)
          end
        }

        def tz_mod.get
          @timezone
        end

        tz_mod.instance_variable_set(:@timezone, defn)
      end
    end
  end
end
