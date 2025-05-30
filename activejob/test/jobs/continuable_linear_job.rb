# frozen_string_literal: true

class ContinuableLinearJob < ActiveJob::Base
  include ActiveJob::Continuable

  cattr_accessor :items

  def perform
    step :step_one
    step :step_two
    step :step_three
    step :step_four
  end

  private
    def step_one
      items << "item1"
    end

    def step_two
      items << "item2"
    end

    def step_three
      items << "item3"
    end

    def step_four
      items << "item4"
    end
end
