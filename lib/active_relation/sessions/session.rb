require 'singleton'

module ActiveRelation
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
        insert.engine.insert(insert.to_sql)
      end
      
      def read(select)
        @read ||= Hash.new do |hash, select|
          hash[select] = select.engine.select_all(select.to_sql)
        end
        @read[select]
      end
      
      def update(update)
        update.engine.update(update.to_sql)
      end
      
      def delete(delete)
        delete.engine.delete(delete.to_sql)
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