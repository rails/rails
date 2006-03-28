module ActiveRecord
  # Active Records support optimistic locking if the field <tt>lock_version</tt> is present.  Each update to the
  # record increments the lock_version column and the locking facilities ensure that records instantiated twice
  # will let the last one saved raise a StaleObjectError if the first was also updated. Example:
  #
  #   p1 = Person.find(1)
  #   p2 = Person.find(1)
  #   
  #   p1.first_name = "Michael"
  #   p1.save
  #   
  #   p2.first_name = "should fail"
  #   p2.save # Raises a ActiveRecord::StaleObjectError
  #
  # You're then responsible for dealing with the conflict by rescuing the exception and either rolling back, merging,
  # or otherwise apply the business logic needed to resolve the conflict.
  #
  # You must ensure that your database schema defaults the lock_version column to 0.
  #
  # This behavior can be turned off by setting <tt>ActiveRecord::Base.lock_optimistically = false</tt>.
  # To override the name of the lock_version column, invoke the <tt>set_locking_column</tt> method.
  # This method uses the same syntax as <tt>set_table_name</tt>
  module Locking
    def self.append_features(base) #:nodoc:
      super
      base.class_eval do
        alias_method :update_without_lock, :update
        alias_method :update, :update_with_lock
      end
    end

    def update_with_lock #:nodoc:
      return update_without_lock unless locking_enabled?

      lock_col = self.class.locking_column
      previous_value = send(lock_col)
      send(lock_col + '=', previous_value + 1)

      affected_rows = connection.update(<<-end_sql, "#{self.class.name} Update with optimistic locking")
        UPDATE #{self.class.table_name}
        SET #{quoted_comma_pair_list(connection, attributes_with_quotes(false))}
        WHERE #{self.class.primary_key} = #{quote(id)} 
        AND #{lock_col} = #{quote(previous_value)}
      end_sql

      unless affected_rows == 1
        raise ActiveRecord::StaleObjectError, "Attempted to update a stale object"
      end

      return true
    end
  end

  class Base
    @@lock_optimistically = true
    cattr_accessor :lock_optimistically

    def locking_enabled? #:nodoc:
      lock_optimistically && respond_to?(self.class.locking_column)
    end
    
    class << self
      def set_locking_column(value = nil, &block)
        define_attr_method :locking_column, value, &block
      end
  
      def locking_column #:nodoc:
        reset_locking_column
      end
  
      def reset_locking_column #:nodoc:
        default = 'lock_version'
        set_locking_column(default)
        default
      end
    end
    
  end
end
