require 'singleton'

module Arel
  class Session    
    class << self
      attr_accessor :instance
      alias_method :manufacture, :new
      
      def start
        if @started
          yield
        else
          begin
            @started = true
            @instance = manufacture
            metaclass.send :alias_method, :new, :instance
            yield
          ensure
            metaclass.send :alias_method, :new, :manufacture
            @started = false
          end
        end
      end
    end
    
    module CRUD
      def create(insert)
        insert.call(insert.engine.connection)
      end
      
      def read(select)
        @read ||= Hash.new do |hash, select|
          hash[select] = select.call(select.engine.connection)
        end
        @read[select]
      end
      
      def update(update)
        update.call(update.engine.connection)
      end
      
      def delete(delete)
        delete.call(delete.engine.connection)
      end
    end
    include CRUD
    
    module Transactions
    end
    include Transactions
    
    module UnitOfWork
    end
    include UnitOfWork
  end
end