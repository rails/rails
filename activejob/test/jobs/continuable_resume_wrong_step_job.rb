# frozen_string_literal: true

class ContinuableResumeWrongStepJob < ActiveJob::Base
  include ActiveJob::Continuable

  def perform
    if continuation.send(:started?)
      step :unexpected do |step|
      end
    else
      step :iterating, start: 0 do |step|
        ((step.cursor || 1)..4).each do |i|
          step.advance!
        end
      end
    end
  end
end
