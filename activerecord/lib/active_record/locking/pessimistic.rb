# frozen_string_literal: true

module ActiveRecord
  module Locking
    # Locking::Pessimistic provides support for row-level locking using
    # SELECT ... FOR UPDATE and other lock types.
    #
    # Chain <tt>ActiveRecord::Base#find</tt> to <tt>ActiveRecord::QueryMethods#lock</tt> to obtain an exclusive
    # lock on the selected rows:
    #   # select * from accounts where id=1 for update
    #   Account.lock.find(1)
    #
    # Call <tt>lock('some locking clause')</tt> to use a database-specific locking clause
    # of your own such as 'LOCK IN SHARE MODE' or 'FOR UPDATE NOWAIT'. Example:
    #
    #   Account.transaction do
    #     # select * from accounts where name = 'shugo' limit 1 for update
    #     shugo = Account.where("name = 'shugo'").lock(true).first
    #     yuko = Account.where("name = 'yuko'").lock(true).first
    #     shugo.balance -= 100
    #     shugo.save!
    #     yuko.balance += 100
    #     yuko.save!
    #   end
    #
    # You can also use <tt>ActiveRecord::Base#lock!</tt> method to lock one record by id.
    # This may be better if you don't need to lock every row. Example:
    #
    #   Account.transaction do
    #     # select * from accounts where ...
    #     accounts = Account.where(...)
    #     account1 = accounts.detect { |account| ... }
    #     account2 = accounts.detect { |account| ... }
    #     # select * from accounts where id=? for update
    #     account1.lock!
    #     account2.lock!
    #     account1.balance -= 100
    #     account1.save!
    #     account2.balance += 100
    #     account2.save!
    #   end
    #
    # You can start a transaction and acquire the lock in one go by calling
    # <tt>with_lock</tt> with a block. The block is called from within
    # a transaction, the object is already locked. Example:
    #
    #   account = Account.first
    #   account.with_lock do
    #     # This block is called within a transaction,
    #     # account is already locked.
    #     account.balance -= 100
    #     account.save!
    #   end
    #
    # Database-specific information on row locking:
    #   MySQL: https://dev.mysql.com/doc/refman/5.7/en/innodb-locking-reads.html
    #   PostgreSQL: https://www.postgresql.org/docs/current/interactive/sql-select.html#SQL-FOR-UPDATE-SHARE
    module Pessimistic
      # Obtain a row lock on this record. Reloads the record to obtain the requested
      # lock. Pass an SQL locking clause to append the end of the SELECT statement
      # or pass true for "FOR UPDATE" (the default, an exclusive row lock). Returns
      # the locked record.
      def lock!(lock = true)
        if persisted?
          if has_changes_to_save?
            raise(<<-MSG.squish)
              Locking a record with unpersisted changes is not supported. Use
              `save` to persist the changes, or `reload` to discard them
              explicitly.
            MSG
          end

          reload(lock: lock)
        end
        self
      end

      # Wraps the passed block in a transaction, locking the object
      # before yielding. You can pass the SQL locking clause
      # as argument (see <tt>lock!</tt>).
      def with_lock(lock = true)
        transaction do
          lock!(lock)
          yield
        end
      end
    end
  end
end
