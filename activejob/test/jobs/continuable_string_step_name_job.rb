# frozen_string_literal: true

class ContinuableStringStepNameJob < ActiveJob::Base
  include ActiveJob::Continuable

  def perform
    step "string_step_name" do |step|
    end
  end
end
