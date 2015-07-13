class Room
  attr_reader :id, :name

  def initialize(id, name='Campfire')
    @id = id
    @name = name
  end

  def to_global_id
    "Room##{id}-#{name}"
  end
end
