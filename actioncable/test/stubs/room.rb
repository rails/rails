# frozen_string_literal: true

class Room
  attr_reader :id, :name

  def initialize(id, name = 'Campfire')
    @id = id
    @name = name
  end

  def to_global_id
    GlobalID.new("Room##{id}-#{name}")
  end

  def to_gid_param
    to_global_id.to_param
  end
end
