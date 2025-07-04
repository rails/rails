# frozen_string_literal: true

module ActiveSupport::EventReporter::TestHelper # :nodoc:
  class EventSubscriber
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

      if source_location
        return false unless event[:source_location][:filepath] == source_location[:filepath] if source_location[:filepath]
        return false unless event[:source_location][:lineno] == source_location[:lineno] if source_location[:lineno]
        return false unless event[:source_location][:label] == source_location[:label] if source_location[:label]
      end

      true
    }
  end
end
