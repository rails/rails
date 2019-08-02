# frozen_string_literal: true

require "active_record/middleware/database_selector/resolver/session"

module ActiveRecord
  module Middleware
    class DatabaseSelector
      # The Resolver class is used by the DatabaseSelector middleware to
      # determine which database the request should use.
      #
      # To change the behavior of the Resolver class in your application,
      # create a custom resolver class that inherits from
      # DatabaseSelector::Resolver and implements the methods that need to
      # be changed.
      #
      # By default the Resolver class will send read traffic to the replica
      # if it's been 2 seconds since the last write.
      class Resolver # :nodoc:
        SEND_TO_REPLICA_DELAY = 2.seconds

        def self.call(context, options = {})
          new(context, options)
        end

        def initialize(context, options = {})
          @context = context
          @options = options
          @delay = @options && @options[:delay] ? @options[:delay] : SEND_TO_REPLICA_DELAY
          @instrumenter = ActiveSupport::Notifications.instrumenter
        end

        attr_reader :context, :delay, :instrumenter

        def read(&blk)
          if read_from_primary?
            read_from_primary(&blk)
          else
            read_from_replica(&blk)
          end
        end

        def write(&blk)
          write_to_primary(&blk)
        end

        private

          def read_from_primary(&blk)
            ActiveRecord::Base.connected_to(role: ActiveRecord::Base.writing_role) do
              ActiveRecord::Base.connection_handler.while_preventing_writes(true) do
                instrumenter.instrument("database_selector.active_record.read_from_primary") do
                  yield
                end
              end
            end
          end

          def read_from_replica(&blk)
            ActiveRecord::Base.connected_to(role: ActiveRecord::Base.reading_role) do
              instrumenter.instrument("database_selector.active_record.read_from_replica") do
                yield
              end
            end
          end

          def write_to_primary(&blk)
            ActiveRecord::Base.connected_to(role: ActiveRecord::Base.writing_role) do
              ActiveRecord::Base.connection_handler.while_preventing_writes(false) do
                instrumenter.instrument("database_selector.active_record.wrote_to_primary") do
                  yield
                ensure
                  context.update_last_write_timestamp
                end
              end
            end
          end

          def read_from_primary?
            !time_since_last_write_ok?
          end

          def send_to_replica_delay
            delay
          end

          def time_since_last_write_ok?
            Time.now - context.last_write_timestamp >= send_to_replica_delay
          end
      end
    end
  end
end
