# :title: Transaction::Simple -- Active Object Transaction Support for Ruby
# :main: Transaction::Simple
#
# == Licence
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#--
# Transaction::Simple
#   Simple object transaction support for Ruby
#   Version 1.3.0
#
# Copyright (c) 2003 - 2005 Austin Ziegler
#
# $Id: simple.rb,v 1.5 2005/05/05 16:16:49 austin Exp $
#++
  # The "Transaction" namespace can be used for additional transaction
  # support objects and modules.
module Transaction
    # A standard exception for transaction errors.
  class TransactionError < StandardError; end
    # The TransactionAborted exception is used to indicate when a
    # transaction has been aborted in the block form.
  class TransactionAborted < Exception; end
    # The TransactionCommitted exception is used to indicate when a
    # transaction has been committed in the block form.
  class TransactionCommitted < Exception; end

  te = "Transaction Error: %s"

  Messages = {
    :bad_debug_object =>
      te % "the transaction debug object must respond to #<<.",
    :unique_names =>
      te % "named transactions must be unique.",
    :no_transaction_open =>
      te % "no transaction open.",
    :cannot_rewind_no_transaction =>
      te % "cannot rewind; there is no current transaction.",
    :cannot_rewind_named_transaction =>
      te % "cannot rewind to transaction %s because it does not exist.",
    :cannot_rewind_transaction_before_block =>
      te % "cannot rewind a transaction started before the execution block.",
    :cannot_abort_no_transaction =>
      te % "cannot abort; there is no current transaction.",
    :cannot_abort_transaction_before_block =>
      te % "cannot abort a transaction started before the execution block.",
    :cannot_abort_named_transaction =>
      te % "cannot abort nonexistant transaction %s.",
    :cannot_commit_no_transaction =>
      te % "cannot commit; there is no current transaction.",
    :cannot_commit_transaction_before_block =>
      te % "cannot commit a transaction started before the execution block.",
    :cannot_commit_named_transaction =>
      te % "cannot commit nonexistant transaction %s.",
    :cannot_start_empty_block_transaction =>
      te % "cannot start a block transaction with no objects.",
    :cannot_obtain_transaction_lock =>
      te % "cannot obtain transaction lock for #%s.",
  }

    # = Transaction::Simple for Ruby
    # Simple object transaction support for Ruby
    #
    # == Introduction
    # Transaction::Simple provides a generic way to add active transaction
    # support to objects. The transaction methods added by this module will
    # work with most objects, excluding those that cannot be
    # <i>Marshal</i>ed (bindings, procedure objects, IO instances, or
    # singleton objects).
    #
    # The transactions supported by Transaction::Simple are not backed
    # transactions; they are not associated with any sort of data store.
    # They are "live" transactions occurring in memory and in the object
    # itself. This is to allow "test" changes to be made to an object
    # before making the changes permanent.
    #
    # Transaction::Simple can handle an "infinite" number of transaction
    # levels (limited only by memory). If I open two transactions, commit
    # the second, but abort the first, the object will revert to the
    # original version.
    # 
    # Transaction::Simple supports "named" transactions, so that multiple
    # levels of transactions can be committed, aborted, or rewound by
    # referring to the appropriate name of the transaction. Names may be any
    # object *except* +nil+. As with Hash keys, String names will be
    # duplicated and frozen before using.
    #
    # Copyright::   Copyright © 2003 - 2005 by Austin Ziegler
    # Version::     1.3.0
    # Licence::     MIT-Style
    #
    # Thanks to David Black for help with the initial concept that led to
    # this library.
    #
    # == Usage
    #   include 'transaction/simple'
    #
    #   v = "Hello, you."               # -> "Hello, you."
    #   v.extend(Transaction::Simple)   # -> "Hello, you."
    #
    #   v.start_transaction             # -> ... (a Marshal string)
    #   v.transaction_open?             # -> true
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #
    #   v.rewind_transaction            # -> "Hello, you."
    #   v.transaction_open?             # -> true
    #
    #   v.gsub!(/you/, "HAL")           # -> "Hello, HAL."
    #   v.abort_transaction             # -> "Hello, you."
    #   v.transaction_open?             # -> false
    #
    #   v.start_transaction             # -> ... (a Marshal string)
    #   v.start_transaction             # -> ... (a Marshal string)
    #
    #   v.transaction_open?             # -> true
    #   v.gsub!(/you/, "HAL")           # -> "Hello, HAL."
    #
    #   v.commit_transaction            # -> "Hello, HAL."
    #   v.transaction_open?             # -> true
    #   v.abort_transaction             # -> "Hello, you."
    #   v.transaction_open?             # -> false
    #
    # == Named Transaction Usage
    #   v = "Hello, you."               # -> "Hello, you."
    #   v.extend(Transaction::Simple)   # -> "Hello, you."
    #   
    #   v.start_transaction(:first)     # -> ... (a Marshal string)
    #   v.transaction_open?             # -> true
    #   v.transaction_open?(:first)     # -> true
    #   v.transaction_open?(:second)    # -> false
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #   
    #   v.start_transaction(:second)    # -> ... (a Marshal string)
    #   v.gsub!(/world/, "HAL")         # -> "Hello, HAL."
    #   v.rewind_transaction(:first)    # -> "Hello, you."
    #   v.transaction_open?             # -> true
    #   v.transaction_open?(:first)     # -> true
    #   v.transaction_open?(:second)    # -> false
    #   
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #   v.start_transaction(:second)    # -> ... (a Marshal string)
    #   v.gsub!(/world/, "HAL")         # -> "Hello, HAL."
    #   v.transaction_name              # -> :second
    #   v.abort_transaction(:first)     # -> "Hello, you."
    #   v.transaction_open?             # -> false
    #   
    #   v.start_transaction(:first)     # -> ... (a Marshal string)
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #   v.start_transaction(:second)    # -> ... (a Marshal string)
    #   v.gsub!(/world/, "HAL")         # -> "Hello, HAL."
    #   
    #   v.commit_transaction(:first)    # -> "Hello, HAL."
    #   v.transaction_open?             # -> false
    #
    # == Block Usage
    #   v = "Hello, you."               # -> "Hello, you."
    #   Transaction::Simple.start(v) do |tv|
    #       # v has been extended with Transaction::Simple and an unnamed
    #       # transaction has been started.
    #     tv.transaction_open?          # -> true
    #     tv.gsub!(/you/, "world")      # -> "Hello, world."
    #
    #     tv.rewind_transaction         # -> "Hello, you."
    #     tv.transaction_open?          # -> true
    #
    #     tv.gsub!(/you/, "HAL")        # -> "Hello, HAL."
    #       # The following breaks out of the transaction block after
    #       # aborting the transaction.
    #     tv.abort_transaction          # -> "Hello, you."
    #   end
    #     # v still has Transaction::Simple applied from here on out.
    #   v.transaction_open?             # -> false
    #
    #   Transaction::Simple.start(v) do |tv|
    #     tv.start_transaction          # -> ... (a Marshal string)
    #
    #     tv.transaction_open?          # -> true
    #     tv.gsub!(/you/, "HAL")        # -> "Hello, HAL."
    #
    #       # If #commit_transaction were called without having started a
    #       # second transaction, then it would break out of the transaction
    #       # block after committing the transaction.
    #     tv.commit_transaction         # -> "Hello, HAL."
    #     tv.transaction_open?          # -> true
    #     tv.abort_transaction          # -> "Hello, you."
    #   end
    #   v.transaction_open?             # -> false
    #
    # == Named Transaction Usage
    #   v = "Hello, you."               # -> "Hello, you."
    #   v.extend(Transaction::Simple)   # -> "Hello, you."
    #   
    #   v.start_transaction(:first)     # -> ... (a Marshal string)
    #   v.transaction_open?             # -> true
    #   v.transaction_open?(:first)     # -> true
    #   v.transaction_open?(:second)    # -> false
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #   
    #   v.start_transaction(:second)    # -> ... (a Marshal string)
    #   v.gsub!(/world/, "HAL")         # -> "Hello, HAL."
    #   v.rewind_transaction(:first)    # -> "Hello, you."
    #   v.transaction_open?             # -> true
    #   v.transaction_open?(:first)     # -> true
    #   v.transaction_open?(:second)    # -> false
    #   
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #   v.start_transaction(:second)    # -> ... (a Marshal string)
    #   v.gsub!(/world/, "HAL")         # -> "Hello, HAL."
    #   v.transaction_name              # -> :second
    #   v.abort_transaction(:first)     # -> "Hello, you."
    #   v.transaction_open?             # -> false
    #   
    #   v.start_transaction(:first)     # -> ... (a Marshal string)
    #   v.gsub!(/you/, "world")         # -> "Hello, world."
    #   v.start_transaction(:second)    # -> ... (a Marshal string)
    #   v.gsub!(/world/, "HAL")         # -> "Hello, HAL."
    #   
    #   v.commit_transaction(:first)    # -> "Hello, HAL."
    #   v.transaction_open?             # -> false
    #
    # == Thread Safety
    # Threadsafe version of Transaction::Simple and
    # Transaction::Simple::Group exist; these are loaded from
    # 'transaction/simple/threadsafe' and
    # 'transaction/simple/threadsafe/group', respectively, and are
    # represented in Ruby code as Transaction::Simple::ThreadSafe and
    # Transaction::Simple::ThreadSafe::Group, respectively.
    #
    # == Contraindications
    # While Transaction::Simple is very useful, it has some severe
    # limitations that must be understood. Transaction::Simple:
    #
    # * uses Marshal. Thus, any object which cannot be <i>Marshal</i>ed
    #   cannot use Transaction::Simple. In my experience, this affects
    #   singleton objects more often than any other object. It may be that
    #   Ruby 2.0 will solve this problem.
    # * does not manage resources. Resources external to the object and its
    #   instance variables are not managed at all. However, all instance
    #   variables and objects "belonging" to those instance variables are
    #   managed. If there are object reference counts to be handled,
    #   Transaction::Simple will probably cause problems.
    # * is not inherently thread-safe. In the ACID ("atomic, consistent,
    #   isolated, durable") test, Transaction::Simple provides CD, but it is
    #   up to the user of Transaction::Simple to provide isolation and
    #   atomicity. Transactions should be considered "critical sections" in
    #   multi-threaded applications. If thread safety and atomicity is
    #   absolutely required, use Transaction::Simple::ThreadSafe, which uses
    #   a Mutex object to synchronize the accesses on the object during the
    #   transaction operations.
    # * does not necessarily maintain Object#__id__ values on rewind or
    #   abort. This may change for future versions that will be Ruby 1.8 or
    #   better *only*. Certain objects that support #replace will maintain
    #   Object#__id__.
    # * Can be a memory hog if you use many levels of transactions on many
    #   objects.
    #
  module Simple
    TRANSACTION_SIMPLE_VERSION = '1.3.0'

      # Sets the Transaction::Simple debug object. It must respond to #<<.
      # Sets the transaction debug object. Debugging will be performed
      # automatically if there's a debug object. The generic transaction
      # error class.
    def self.debug_io=(io)
      if io.nil?
        @tdi        = nil
        @debugging  = false
      else
        unless io.respond_to?(:<<)
          raise TransactionError, Messages[:bad_debug_object]
        end
        @tdi = io
        @debugging = true
      end
    end

      # Returns +true+ if we are debugging.
    def self.debugging?
      @debugging
    end

      # Returns the Transaction::Simple debug object. It must respond to
      # #<<.
    def self.debug_io
      @tdi ||= ""
      @tdi
    end

      # If +name+ is +nil+ (default), then returns +true+ if there is
      # currently a transaction open.
      #
      # If +name+ is specified, then returns +true+ if there is currently a
      # transaction that responds to +name+ open.
    def transaction_open?(name = nil)
      if name.nil?
        if Transaction::Simple.debugging?
          Transaction::Simple.debug_io << "Transaction " <<
            "[#{(@__transaction_checkpoint__.nil?) ? 'closed' : 'open'}]\n"
        end
        return (not @__transaction_checkpoint__.nil?)
      else
        if Transaction::Simple.debugging?
          Transaction::Simple.debug_io << "Transaction(#{name.inspect}) " <<
            "[#{(@__transaction_checkpoint__.nil?) ? 'closed' : 'open'}]\n"
        end
        return ((not @__transaction_checkpoint__.nil?) and @__transaction_names__.include?(name))
      end
    end

      # Returns the current name of the transaction. Transactions not
      # explicitly named are named +nil+.
    def transaction_name
      if @__transaction_checkpoint__.nil?
        raise TransactionError, Messages[:no_transaction_open]
      end
      if Transaction::Simple.debugging?
        Transaction::Simple.debug_io << "#{'|' * @__transaction_level__} " <<
          "Transaction Name: #{@__transaction_names__[-1].inspect}\n"
      end
      if @__transaction_names__[-1].kind_of?(String)
        @__transaction_names__[-1].dup
      else
        @__transaction_names__[-1]
      end
    end

      # Starts a transaction. Stores the current object state. If a
      # transaction name is specified, the transaction will be named.
      # Transaction names must be unique. Transaction names of +nil+ will be
      # treated as unnamed transactions.
    def start_transaction(name = nil)
      @__transaction_level__ ||= 0
      @__transaction_names__ ||= []

      if name.nil?
        @__transaction_names__ << nil
        ss = "" if Transaction::Simple.debugging?
      else
        if @__transaction_names__.include?(name)
          raise TransactionError, Messages[:unique_names]
        end
        name = name.dup.freeze if name.kind_of?(String)
        @__transaction_names__ << name
        ss = "(#{name.inspect})" if Transaction::Simple.debugging?
      end

      @__transaction_level__ += 1

      if Transaction::Simple.debugging?
        Transaction::Simple.debug_io << "#{'>' * @__transaction_level__} " <<
          "Start Transaction#{ss}\n"
      end

      @__transaction_checkpoint__ = Marshal.dump(self)
    end

      # Rewinds the transaction. If +name+ is specified, then the
      # intervening transactions will be aborted and the named transaction
      # will be rewound. Otherwise, only the current transaction is rewound.
    def rewind_transaction(name = nil)
      if @__transaction_checkpoint__.nil?
        raise TransactionError, Messages[:cannot_rewind_no_transaction]
      end

        # Check to see if we are trying to rewind a transaction that is
        # outside of the current transaction block.
      if @__transaction_block__ and name
        nix = @__transaction_names__.index(name) + 1
        if nix < @__transaction_block__
          raise TransactionError, Messages[:cannot_rewind_transaction_before_block]
        end
      end

      if name.nil?
        __rewind_this_transaction
        ss = "" if Transaction::Simple.debugging?
      else
        unless @__transaction_names__.include?(name)
          raise TransactionError, Messages[:cannot_rewind_named_transaction] % name.inspect
        end
        ss = "(#{name})" if Transaction::Simple.debugging?

        while @__transaction_names__[-1] != name
          @__transaction_checkpoint__ = __rewind_this_transaction
          if Transaction::Simple.debugging?
            Transaction::Simple.debug_io << "#{'|' * @__transaction_level__} " <<
              "Rewind Transaction#{ss}\n"
          end
          @__transaction_level__ -= 1
          @__transaction_names__.pop
        end
        __rewind_this_transaction
      end
      if Transaction::Simple.debugging?
        Transaction::Simple.debug_io << "#{'|' * @__transaction_level__} " <<
          "Rewind Transaction#{ss}\n"
      end
      self
    end

      # Aborts the transaction. Resets the object state to what it was
      # before the transaction was started and closes the transaction. If
      # +name+ is specified, then the intervening transactions and the named
      # transaction will be aborted. Otherwise, only the current transaction
      # is aborted.
      #
      # If the current or named transaction has been started by a block
      # (Transaction::Simple.start), then the execution of the block will be
      # halted with +break+ +self+.
    def abort_transaction(name = nil)
      if @__transaction_checkpoint__.nil?
        raise TransactionError, Messages[:cannot_abort_no_transaction]
      end

        # Check to see if we are trying to abort a transaction that is
        # outside of the current transaction block. Otherwise, raise
        # TransactionAborted if they are the same.
      if @__transaction_block__ and name
        nix = @__transaction_names__.index(name) + 1
        if nix < @__transaction_block__
          raise TransactionError, Messages[:cannot_abort_transaction_before_block]
        end

        raise TransactionAborted if @__transaction_block__ == nix
      end

      raise TransactionAborted if @__transaction_block__ == @__transaction_level__

      if name.nil?
        __abort_transaction(name)
      else
        unless @__transaction_names__.include?(name)
          raise TransactionError, Messages[:cannot_abort_named_transaction] % name.inspect
        end
        __abort_transaction(name) while @__transaction_names__.include?(name)
      end
      self
    end

      # If +name+ is +nil+ (default), the current transaction level is
      # closed out and the changes are committed.
      #
      # If +name+ is specified and +name+ is in the list of named
      # transactions, then all transactions are closed and committed until
      # the named transaction is reached.
    def commit_transaction(name = nil)
      if @__transaction_checkpoint__.nil?
        raise TransactionError, Messages[:cannot_commit_no_transaction]
      end
      @__transaction_block__ ||= nil

        # Check to see if we are trying to commit a transaction that is
        # outside of the current transaction block. Otherwise, raise
        # TransactionCommitted if they are the same.
      if @__transaction_block__ and name
        nix = @__transaction_names__.index(name) + 1
        if nix < @__transaction_block__
          raise TransactionError, Messages[:cannot_commit_transaction_before_block]
        end

        raise TransactionCommitted if @__transaction_block__ == nix
      end

      raise TransactionCommitted if @__transaction_block__ == @__transaction_level__

      if name.nil?
        ss = "" if Transaction::Simple.debugging?
        __commit_transaction
        if Transaction::Simple.debugging?
          Transaction::Simple.debug_io << "#{'<' * @__transaction_level__} " <<
            "Commit Transaction#{ss}\n"
        end
      else
        unless @__transaction_names__.include?(name)
          raise TransactionError, Messages[:cannot_commit_named_transaction] % name.inspect
        end
        ss = "(#{name})" if Transaction::Simple.debugging?

        while @__transaction_names__[-1] != name
          if Transaction::Simple.debugging?
            Transaction::Simple.debug_io << "#{'<' * @__transaction_level__} " <<
              "Commit Transaction#{ss}\n"
          end
          __commit_transaction
        end
        if Transaction::Simple.debugging?
          Transaction::Simple.debug_io << "#{'<' * @__transaction_level__} " <<
            "Commit Transaction#{ss}\n"
        end
        __commit_transaction
      end

      self
    end

      # Alternative method for calling the transaction methods. An optional
      # name can be specified for named transaction support.
      #
      # #transaction(:start)::  #start_transaction
      # #transaction(:rewind):: #rewind_transaction
      # #transaction(:abort)::  #abort_transaction
      # #transaction(:commit):: #commit_transaction
      # #transaction(:name)::   #transaction_name
      # #transaction::          #transaction_open?
    def transaction(action = nil, name = nil)
      case action
      when :start
        start_transaction(name)
      when :rewind
        rewind_transaction(name)
      when :abort
        abort_transaction(name)
      when :commit
        commit_transaction(name)
      when :name
        transaction_name
      when nil
        transaction_open?(name)
      end
    end

      # Allows specific variables to be excluded from transaction support.
      # Must be done after extending the object but before starting the
      # first transaction on the object.
      #
      #   vv.transaction_exclusions << "@io"
    def transaction_exclusions
      @transaction_exclusions ||= []
    end

    class << self
      def __common_start(name, vars, &block)
        if vars.empty?
          raise TransactionError, Messages[:cannot_start_empty_block_transaction]
        end

        if block
          begin
            vlevel = {}

            vars.each do |vv|
              vv.extend(Transaction::Simple)
              vv.start_transaction(name)
              vlevel[vv.__id__] = vv.instance_variable_get(:@__transaction_level__)
              vv.instance_variable_set(:@__transaction_block__, vlevel[vv.__id__])
            end

            yield(*vars)
          rescue TransactionAborted
            vars.each do |vv|
              if name.nil? and vv.transaction_open?
                loop do
                  tlevel = vv.instance_variable_get(:@__transaction_level__) || -1
                  vv.instance_variable_set(:@__transaction_block__, -1)
                  break if tlevel < vlevel[vv.__id__]
                  vv.abort_transaction if vv.transaction_open?
                end
              elsif vv.transaction_open?(name)
                vv.instance_variable_set(:@__transaction_block__, -1)
                vv.abort_transaction(name)
              end
            end
          rescue TransactionCommitted
            nil
          ensure
            vars.each do |vv|
              if name.nil? and vv.transaction_open?
                loop do
                  tlevel = vv.instance_variable_get(:@__transaction_level__) || -1
                  break if tlevel < vlevel[vv.__id__]
                  vv.instance_variable_set(:@__transaction_block__, -1)
                  vv.commit_transaction if vv.transaction_open?
                end
              elsif vv.transaction_open?(name)
                vv.instance_variable_set(:@__transaction_block__, -1)
                vv.commit_transaction(name)
              end
            end
          end
        else
          vars.each do |vv|
            vv.extend(Transaction::Simple)
            vv.start_transaction(name)
          end
        end
      end
      private :__common_start

      def start_named(name, *vars, &block)
        __common_start(name, vars, &block)
      end

      def start(*vars, &block)
        __common_start(nil, vars, &block)
      end
    end

    def __abort_transaction(name = nil) #:nodoc:
      @__transaction_checkpoint__ = __rewind_this_transaction

      if name.nil?
        ss = "" if Transaction::Simple.debugging?
      else
        ss = "(#{name.inspect})" if Transaction::Simple.debugging?
      end

      if Transaction::Simple.debugging?
        Transaction::Simple.debug_io << "#{'<' * @__transaction_level__} " <<
          "Abort Transaction#{ss}\n"
      end
      @__transaction_level__ -= 1
      @__transaction_names__.pop
      if @__transaction_level__ < 1
        @__transaction_level__ = 0
        @__transaction_names__ = []
      end
    end

    TRANSACTION_CHECKPOINT  = "@__transaction_checkpoint__" #:nodoc:
    SKIP_TRANSACTION_VARS   = [TRANSACTION_CHECKPOINT, "@__transaction_level__"] #:nodoc:

    def __rewind_this_transaction #:nodoc:
      rr = Marshal.restore(@__transaction_checkpoint__)

      begin
        self.replace(rr) if respond_to?(:replace)
      rescue
        nil
      end

      rr.instance_variables.each do |vv|
        next if SKIP_TRANSACTION_VARS.include?(vv)
        next if self.transaction_exclusions.include?(vv)
        if respond_to?(:instance_variable_get)
          instance_variable_set(vv, rr.instance_variable_get(vv))
        else
          instance_eval(%q|#{vv} = rr.instance_eval("#{vv}")|)
        end
      end

      new_ivar = instance_variables - rr.instance_variables - SKIP_TRANSACTION_VARS
      new_ivar.each do |vv|
        if respond_to?(:instance_variable_set)
          instance_variable_set(vv, nil)
        else
          instance_eval(%q|#{vv} = nil|)
        end
      end

      if respond_to?(:instance_variable_get)
        rr.instance_variable_get(TRANSACTION_CHECKPOINT)
      else
        rr.instance_eval(TRANSACTION_CHECKPOINT)
      end
    end

    def __commit_transaction #:nodoc:
      if respond_to?(:instance_variable_get)
        @__transaction_checkpoint__ = Marshal.restore(@__transaction_checkpoint__).instance_variable_get(TRANSACTION_CHECKPOINT)
      else
        @__transaction_checkpoint__ = Marshal.restore(@__transaction_checkpoint__).instance_eval(TRANSACTION_CHECKPOINT)
      end

      @__transaction_level__ -= 1
      @__transaction_names__.pop

      if @__transaction_level__ < 1
        @__transaction_level__ = 0
        @__transaction_names__ = []
      end
    end

    private :__abort_transaction
    private :__rewind_this_transaction
    private :__commit_transaction
  end
end
