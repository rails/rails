# frozen_string_literal: true

# Rough approximation of the AR batch iterator
ContinuableIteratingRecord = Struct.new(:id, :name) do
  cattr_accessor :records

  def self.find_each(start: nil)
    records.sort_by(&:id).each do |record|
      next if start && record.id < start

      yield record
    end
  end
end

class ContinuableIteratingJob < ActiveJob::Base
  include ActiveJob::Continuable

  def perform(raise_when_cursor: nil)
    step :rename do |step|
      ContinuableIteratingRecord.find_each(start: step.cursor) do |record|
        raise StandardError, "Cursor error" if raise_when_cursor && step.cursor == raise_when_cursor
        record.name = "new_#{record.name}"
        step.advance! from: record.id
      end
    end
  end
end
