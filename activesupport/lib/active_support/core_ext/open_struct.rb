require 'ostruct'

class OpenStruct
  def []=(key, value)
    self.send("#{key}=", value)
  end

  def [](key)
    send(key)
  end
end