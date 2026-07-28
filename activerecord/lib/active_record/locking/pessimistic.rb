# frozen_string_literal: true

module ActiveRecord
  module Locking
    # = \Pessimistic \Locking
    #
    # Locking::Pessimistic provides support for row-level locking using
    # SELECT ... FOR UPDATE and other lock types.
    #
    # Chain <tt>ActiveRecord::Base#find</tt> to ActiveRecord::QueryMethods#lock to obtain an exclusive
    # lock on the selected rows:
    #   # select * from accounts where id=1 for update
    #   Account.lock.find(1)
    #
    # Call <tt>lock('some locking clause')</tt> to use a database-specific locking clause
    # of your own such as 'LOCK IN SHARE MODE' or 'FOR UPDATE NOWAIT'. Example:
    #
    #   Account.transaction do
    #     # select * from accounts where name = 'shugo' limit 1 for update nowait
    #     shugo = Account.lock("FOR UPDATE NOWAIT").find_by(name: "shugo")
    #     yuko = Account.lock("FOR UPDATE NOWAIT").find_by(name: "yuko")
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
    # a transaction, the object is already locked, and the transaction is
    # yielded so you can register callbacks. Example:
    #
    #   account = Account.first
    #   account.with_lock do |transaction|
    #     # This block is called within a transaction,
    #     # account is already locked.
    #     transaction.after_commit { puts "hello" }
    #     account.balance -= 100
    #     account.save!
    #   end
    #
    # == Lock strengths
    #
    # Instead of a raw SQL clause, you can request a named lock strength as a
    # Symbol. The clause is resolved by the database adapter, and an
    # ArgumentError is raised when the adapter does not support the requested
    # strength:
    #
    #   account.with_lock(:no_key_update) do
    #     # SELECT ... FOR NO KEY UPDATE
    #     account.update!(balance: account.balance - 100)
    #   end
    #
    # [+:update+]
    #   <tt>FOR UPDATE</tt>. The strongest row lock — what +true+ requests.
    #   All adapters.
    # [+:no_key_update+]
    #   <tt>FOR NO KEY UPDATE</tt>. Behaves like <tt>FOR UPDATE</tt> towards
    #   other writers, but does not conflict with <tt>FOR KEY SHARE</tt>.
    #   \PostgreSQL only.
    # [+:share+]
    #   <tt>FOR SHARE</tt> (\PostgreSQL) / <tt>LOCK IN SHARE MODE</tt>
    #   (\MySQL). A shared lock: blocks writers, allows other shared locks.
    # [+:key_share+]
    #   <tt>FOR KEY SHARE</tt>. The weakest strength: only blocks
    #   key-modifying writes and +DELETE+. \PostgreSQL only.
    #
    # === Row locks and foreign keys (PostgreSQL)
    #
    # On \PostgreSQL, <tt>FOR UPDATE</tt> interacts with foreign keys in a way
    # that is easy to miss: inserting a row into a table whose foreign key
    # references a locked row makes the referential integrity check take
    # <tt>FOR KEY SHARE</tt> on the referenced row — and <tt>FOR KEY SHARE</tt>
    # conflicts with <tt>FOR UPDATE</tt> (and with nothing weaker). While a
    # transaction holds <tt>FOR UPDATE</tt> on a parent row, every +INSERT+ of
    # a child row referencing it blocks, even though those inserts never touch
    # the parent. Long-held <tt>FOR UPDATE</tt> locks on hot parent rows can
    # therefore starve completely unrelated inserts until they exceed
    # +statement_timeout+ ("canceling statement due to statement timeout ...
    # while locking tuple").
    #
    # When the critical section only updates non-key columns of the locked row
    # (balances, counters, state columns), <tt>:no_key_update</tt> provides the
    # same mutual exclusion between writers without blocking those child
    # inserts. Note that an +UPDATE+ of a column covered by a unique index, or
    # a +DELETE+ of the locked row, still escalates to the stronger lock —
    # keep <tt>:update</tt> (the default) when the critical section deletes
    # the row, changes key columns, or relies on child inserts being blocked
    # (for example, checking an invariant over the row's children).
    #
    # Database-specific information on row locking:
    #
    # [MySQL]
    #   https://dev.mysql.com/doc/refman/en/innodb-locking-reads.html
    #
    # [PostgreSQL]
    #   https://www.postgresql.org/docs/current/interactive/sql-select.html#SQL-FOR-UPDATE-SHARE
    module Pessimistic
      # Obtain a row lock on this record. Reloads the record to obtain the requested
      # lock. Pass an SQL locking clause to append the end of the SELECT statement
      # or pass true for "FOR UPDATE" (the default, an exclusive row lock), or a
      # Symbol naming a lock strength (see ActiveRecord::Locking::Pessimistic).
      # Returns the locked record.
      def lock!(lock = true)
        if self.class.current_preventing_writes
          raise ActiveRecord::ReadOnlyError, "Lock query attempted while in readonly mode"
        end

        if persisted?
          if has_changes_to_save?
            raise(<<-MSG.squish)
              Locking a record with unpersisted changes is not supported. Use
              `save` to persist the changes, or `reload` to discard them
              explicitly.
              Changed attributes: #{changed.map(&:inspect).join(', ')}.
            MSG
          end

          reload(lock: lock)
        end

        self
      end

      # Wraps the passed block in a transaction, reloading the object with a
      # lock before yielding. Yields the current transaction so you can
      # register callbacks. You can pass the SQL locking clause or a lock
      # strength Symbol as an optional argument (see #lock!).
      #
      # You can also pass options like <tt>requires_new:</tt>, <tt>isolation:</tt>,
      # and <tt>joinable:</tt> to the wrapping transaction (see
      # ActiveRecord::ConnectionAdapters::DatabaseStatements#transaction).
      def with_lock(*args)
        transaction_opts = args.extract_options!
        lock = args.present? ? args.first : true
        transaction(**transaction_opts) do |transaction|
          lock!(lock)
          yield transaction
        end
      end
    end
  end
end
