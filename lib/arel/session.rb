module Arel
  class Session
    class << self
      attr_accessor :instance
      alias_method :manufacture, :new

      def start
        if defined?(@started) && @started
          yield
        else
          begin
            @started = true
            @instance = manufacture
            singleton_class.class_eval do
              undef :new
              alias_method :new, :instance
            end
            yield
          ensure
            singleton_class.class_eval do
              undef :new
              alias_method :new, :manufacture
            end
            @started = false
          end
        end
      end
    end

    module CRUD
      def create(insert)
        insert.call
      end

      def read(select)
        (@read ||= Hash.new do |hash, select|
          hash[select] = select.call
        end)[select]
      end

      def update(update)
        update.call
      end

      def delete(delete)
        delete.call
      end
    end
    include CRUD
  end
end
