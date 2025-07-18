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
      return false unless hash_matches?(event[:payload], payload)
      return false unless hash_matches?(event[:tags], tags)
      return false unless hash_matches?(event[:context], context)

      if source_location
        [:filepath, :lineno, :label].each do |key|
          return false unless event[:source_location][key] == source_location[key] if source_location[key]
        end
      end

      true
    }
  end

  private
    def hash_matches?(actual, expected)
      return true if actual.nil? && expected.nil?
      return false if actual.nil? || expected.nil?

      return actual == expected unless actual.is_a?(Hash) && expected.is_a?(Hash)

      return false unless actual.size == expected.size

      expected.each do |key, value|
        return false unless actual[key] == value
      end

      true
    end
end
