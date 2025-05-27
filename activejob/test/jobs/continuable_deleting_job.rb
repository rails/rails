# frozen_string_literal: true

class ContinuableDeletingJob < ActiveJob::Base
  include ActiveJob::Continuable

  cattr_accessor :items

  def perform
    step :delete do |step|
      loop do
        break if items.empty?
        items.shift
        step.checkpoint!
      end
    end
  end
end
