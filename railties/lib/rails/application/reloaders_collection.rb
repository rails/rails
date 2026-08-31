# frozen_string_literal: true

module Rails
  class Application < Engine
    # Wraps the application's set of file reloaders. When a reloader is removed
    # from the collection (via +clear+ or +delete+), its +deactivate+ method is
    # called so it can clean up external state such as registered callbacks.
    class ReloadersCollection # :nodoc:
      include Enumerable

      def initialize
        @reloaders = []
      end

      def each(&block)
        @reloaders.each(&block)
      end

      def <<(reloader)
        @reloaders << reloader
        self
      end

      def size
        @reloaders.size
      end

      def empty?
        @reloaders.empty?
      end

      def clear
        @reloaders.each { |r| r.deactivate if r.respond_to?(:deactivate) }
        @reloaders.clear
      end

      def delete(reloader)
        reloader.deactivate if reloader.respond_to?(:deactivate)
        @reloaders.delete(reloader)
      end
    end
  end
end
