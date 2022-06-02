# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"

class ProtectedParams
  delegate :keys, :key?, :has_key?, :empty?, to: :@parameters

  def initialize(parameters = {})
    @parameters = parameters.with_indifferent_access
    @permitted = false
  end

  def permitted?
    @permitted
  end

  def permit!
    @permitted = true
    self
  end

  def [](key)
    @parameters[key]
  end

  def to_h
    @parameters.to_h
  end
  alias to_unsafe_h to_h

  def each_pair(&block)
    @parameters.each_pair(&block)
  end

  def dup
    super.tap do |duplicate|
      duplicate.instance_variable_set :@permitted, @permitted
    end
  end
end
