# frozen_string_literal: true

class ContinuableNestedStepsJob < ActiveJob::Base
  include ActiveJob::Continuable

  def perform
    step :outer_step do
      # Not allowed!
      step :inner_step do
      end
    end
  end

  private
    def inner_step; end
end
