# frozen_string_literal: true

class ContinuableNestedCursorJob < ActiveJob::Base
  include ActiveJob::Continuable

  cattr_accessor :items

  def perform
    step :updating_sub_items, start: [ 0, 0 ] do |step|
      items[step.cursor[0]..].each do |inner_items|
        inner_items[step.cursor[1]..].each do |item|
          items[step.cursor[0]][step.cursor[1]] = "new_#{item}"

          step.set! [ step.cursor[0], step.cursor[1] + 1 ]
        end

        step.set! [ step.cursor[0] + 1, 0 ]
      end
    end
  end
end
