# frozen_string_literal: true

module ActionCable
  module Channel
    module Streams
      module History
        extend ActiveSupport::Concern

        prepended do
          def stream_handler(broadcasting, user_handler, coder: nil)
            -> message do
              super.(message)
              stream_history_saver(broadcasting).(message) if streams_history[broadcasting]
            end
          end

          def stream_history_saver(broadcasting)
            -> message do
              key = streams_history[broadcasting][:key]
              pubsub.save_history key, message
              logger.info "#{self.class.name} saved message #{message} streamed from #{broadcasting}"
            end
          end

          def stream_history_transmitter
            -> since do
              streams_history.each do |broadcasting, options|
                stream_history = pubsub
                  .read_history(options[:key], since: since)
                  .values
                  .first

                stream_history.each do |_timestamp, entry|
                  message = ActiveSupport::JSON.decode entry["message"]
                  stream_transmitter(broadcasting: broadcasting).(message)
                end

                stream_history_cleaner.(options[:key], since)
              end
            end
          end

          def stream_history_cleaner
            -> (key, since) do
              pubsub.delete_history key, since: since
              logger.info "#{key} cleared"
            end
          end
        end
      end
    end
  end
end
