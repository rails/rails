module AbstractController
  class Base
    
    attr_internal :response_body
    attr_internal :response_obj
    cattr_accessor :logger
        
    def self.process(action)
      new.process(action)
    end
    
    def initialize
      self.response_obj = {}
    end
    
    def process(action)
      send(action)
      self.response_obj[:body] = self.response_body
      self
    end
    
  end
end