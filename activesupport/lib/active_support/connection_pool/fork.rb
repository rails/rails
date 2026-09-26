# :markup: markdown
# frozen_string_literal: true

#
# Source: connection_pool 5a3d762481b9ec46b7cfdf643f8597bd3fc5f02d, https://github.com/mperham/connection_pool/tree/main
#
# Copyright (c) 2011 Mike Perham
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module ActiveSupport
  class ConnectionPool # :nodoc:
    if Process.respond_to?(:fork)
      require "active_support/fork_tracker"

      INSTANCES = ObjectSpace::WeakMap.new # :nodoc:
      private_constant :INSTANCES

      def self.after_fork
        INSTANCES.each_value do |pool|
          # We're in after_fork, so we know all other threads are dead.
          # All we need to do is ensure the main thread doesn't have a
          # checked out connection
          pool.checkin(force: true)
          pool.reload do |connection|
            # Unfortunately we don't know what method to call to close the connection,
            # so we try the most common one.
            connection.close if connection.respond_to?(:close)
          end
        end
        nil
      end

      ActiveSupport::ForkTracker.after_fork { ActiveSupport::ConnectionPool.after_fork }
    else
      # JRuby, et al
      INSTANCES = nil # :nodoc:
      private_constant :INSTANCES

      def self.after_fork
        # noop
      end
    end
  end
end
