require "active_support/concern"

module ActiveSupport
  module Configurable
    extend ActiveSupport::Concern

    module ClassMethods
      def get_config
        module_parts = name.split("::")
        modules = [Object]
        module_parts.each {|name| modules.push modules.last.const_get(name) }
        modules.reverse_each do |mod|
          return mod.const_get(:DEFAULT_CONFIG) if const_defined?(:DEFAULT_CONFIG)
        end
        {}
      end
      
      def config
        self.config = get_config unless @config
        @config
      end

      def config=(hash)
        @config = ActiveSupport::OrderedOptions.new
        hash.each do |key, value|
          @config[key] = value
        end
      end
    end

    def config
      self.class.config
    end
  end
end