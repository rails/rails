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

          # Converts time to a timestamp that represents milliseconds since
          # epoch.
          def self.convert_time_to_timestamp(time)
            time.to_i * 1000 + time.usec / 1000
          end

          # Converts milliseconds since epoch timestamp into a time object.
          def self.convert_timestamp_to_time(timestamp)
            timestamp ? Time.at(timestamp / 1000, (timestamp % 1000) * 1000) : Time.at(0)
          end

          def initialize(session)
            @session = session
          end

          attr_reader :session

          def last_write_timestamp
            self.class.convert_timestamp_to_time(session[:last_write])
          end

          def update_last_write_timestamp
            session[:last_write] = self.class.convert_time_to_timestamp(Time.now)
          end

          def save(response)
          end
        end
      end
    end
  end
end
