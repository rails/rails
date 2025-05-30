# frozen_string_literal: true

class ContinuableDuplicateStepJob < ActiveJob::Base
  include ActiveJob::Continuable

  def perform
    step :duplicate do |step|
    end
    step :duplicate do |step|
    end
  end
end
