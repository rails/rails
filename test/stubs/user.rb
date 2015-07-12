class User
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def to_global_id
    "User##{name}"
  end
end
