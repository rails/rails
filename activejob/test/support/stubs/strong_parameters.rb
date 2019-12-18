# frozen_string_literal: true

class Parameters
  def initialize(parameters = {})
    @parameters = parameters.with_indifferent_access
  end

  def permitted?
    true
  end

  def to_h
    @parameters.to_h
  end
end
