# frozen_string_literal: true

module ActiveRecord
  module Middleware
    class DatabaseSelector
      class Resolver
        # The session class is used by the DatabaseSelector::Resolver to save
        # timestamps of the last write in the session.
        #
        # The last_write is used to determine whether it's safe to read
        # from the replica or the request needs to be sent to the primary.
        class Session # :nodoc:
          def self.call(request)
            new(request.session)
          end

          def initialize(session)
            @session = session
          end

          attr_reader :session

          def last_write_timestamp
            session[:last_write]
          end

          def update_last_write_timestamp
            session[:last_write] = Concurrent.monotonic_time
          end

          def save(response)
          end
        end
      end
    end
  end
end
