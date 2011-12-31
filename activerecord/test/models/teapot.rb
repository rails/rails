class Teapot
  # I'm a little teapot,
  # Short and stout,
  # Here is my handle
  # Here is my spout
  # When I get all steamed up,
  # Hear me shout,
  # Tip me over and pour me out!
  #
  # HELL YEAH TEAPOT SONG

  include ActiveRecord::Model
end

class OtherTeapot < Teapot
end

class OMFGIMATEAPOT
  def aaahhh
    "mmm"
  end
end

class CoolTeapot < OMFGIMATEAPOT
  include ActiveRecord::Model
  self.table_name = "teapots"
end

class Ceiling
  include ActiveRecord::Model

  class Teapot
    include ActiveRecord::Model
  end
end
