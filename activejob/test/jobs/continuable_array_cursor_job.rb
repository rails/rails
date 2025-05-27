# frozen_string_literal: true

class ContinuableArrayCursorJob < ActiveJob::Base
  include ActiveJob::Continuable

  cattr_accessor :items, default: []

  def perform(objects)
    step :iterate_objects, start: 0 do |step|
      objects[step.cursor..].each do |object|
        items << object
        step.advance!
      end
    end
  end
end
