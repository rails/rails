# frozen_string_literal: true

class Parameters
  delegate :to_h, to: :@parameters

  def initialize(parameters = {})
    @parameters = parameters.with_indifferent_access
  end

  def permitted
    true
  end

  def permit(*filters)
    @parameters
  end
end
