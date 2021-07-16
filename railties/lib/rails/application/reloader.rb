# frozen_string_literal: true

require "active_support/reloader"

module Rails
  class Application
    class Reloader < ::ActiveSupport::Reloader
      class_attribute :registered_reloaders, default: {}

      def self.register(name, &block)
        registered_reloaders[name] = block
      end

      def self.fetch(name)
        reloaders[name]
      end

      def self.should_reload?
        reloaders.any? { |_, reloader| reloader.updated? }
      end

      def self.reloaders
        @reloaders ||= begin
          reloaders = {}

          registered_reloaders.each do |name, block|
            reloaders[name] = block.call
          end

          reloaders
        end
      end
      private_class_method :reloaders
    end
  end
end
