# frozen_string_literal: true

module ActiveSupport::EventReporter::TestHelper # :nodoc:
  class EventSubscriber # :nodoc:
    attr_reader :events

    def initialize
      @events = []
    end

    def emit(event)
      @events << event
    end
  end

  def event_matcher(name:, payload: nil, tags: {}, context: {}, source_location: nil)
    ->(event) {
      return false unless event[:name] == name
      return false unless event[:payload] == payload
      return false unless event[:tags] == tags
      return false unless event[:context] == context

      [:filepath, :lineno, :label].each do |key|
        if source_location && source_location[key]
          return false unless event[:source_location][key] == source_location[key]
        end
      end

      true
    }
  end
end
