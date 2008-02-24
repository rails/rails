require 'singleton'

module ActiveRelation
  class Session
    include Singleton
        
    module CRUD
      def connection
        ActiveRecord::Base.connection
      end
      
      def create(insert)
        connection.insert(insert.to_sql)
      end
      
      def read(select)
        connection.select_all(select.to_sql)
      end
      
      def update(update)
        connection.update(update.to_sql)
      end
      
      def delete(delete)
        connection.delete(delete.to_sql)
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