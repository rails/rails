require 'singleton'

module ActiveRelation
  class Session
    class << self
      def start
        if @started
          yield
        else
          begin
            @started = true
            @instance = new
            manufacture = method(:new)
            metaclass.class_eval do
              define_method(:new) { @instance }
            end
            yield
          ensure
            metaclass.class_eval do
              define_method(:new, &manufacture)
            end
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
        @read ||= {}
        @read.has_key?(select) ? @read[select] : (@read[select] = select.engine.select_all(select.to_sql))
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