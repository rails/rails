# Copyright (c) 2006 Shugo Maeda <shugo@ruby-lang.org>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
# ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


module ActiveRecord
  module Locking
    # Locking::Pessimistic provides support for row-level locking using
    # SELECT ... FOR UPDATE and other lock types.
    #
    # Pass <tt>:lock => true</tt> to ActiveRecord::Base.find to obtain an exclusive
    # lock on the selected rows:
    #   # select * from accounts where id=1 for update
    #   Account.find(1, :lock => true)
    #
    # Pass <tt>:lock => 'some locking clause'</tt> to give a database-specific locking clause
    # of your own such as 'LOCK IN SHARE MODE' or 'FOR UPDATE NOWAIT'.
    #
    # Example:
    #   Account.transaction do
    #     # select * from accounts where name = 'shugo' limit 1 for update
    #     shugo = Account.find(:first, :conditions => "name = 'shugo'", :lock => true)
    #     yuko = Account.find(:first, :conditions => "name = 'yuko'", :lock => true)
    #     shugo.balance -= 100
    #     shugo.save!
    #     yuko.balance += 100
    #     yuko.save!
    #   end
    #
    # You can also use ActiveRecord::Base#lock! method to lock one record by id.
    # This may be better if you don't need to lock every row. Example:
    #   Account.transaction do
    #     # select * from accounts where ...
    #     accounts = Account.find(:all, :conditions => ...)
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
    # Database-specific information on row locking:
    #   MySQL: http://dev.mysql.com/doc/refman/5.1/en/innodb-locking-reads.html
    #   PostgreSQL: http://www.postgresql.org/docs/8.1/interactive/sql-select.html#SQL-FOR-UPDATE-SHARE
    module Pessimistic
      # Obtain a row lock on this record. Reloads the record to obtain the requested
      # lock. Pass an SQL locking clause to append the end of the SELECT statement
      # or pass true for "FOR UPDATE" (the default, an exclusive row lock).  Returns
      # the locked record.
      def lock!(lock = true)
        reload(:lock => lock) unless new_record?
        self
      end
    end
  end
end
