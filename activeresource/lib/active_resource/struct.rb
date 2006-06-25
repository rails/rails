module ActiveResource
  class Struct
    def self.create
      Class.new(Base)
    end
  end
end