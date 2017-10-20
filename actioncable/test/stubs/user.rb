# frozen_string_literal: true

class User
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def to_global_id
    GlobalID.new("User##{name}")
  end

  def to_gid_param
    to_global_id.to_param
  end
end
