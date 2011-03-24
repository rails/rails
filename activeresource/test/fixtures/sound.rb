module Asset  
  class Sound < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000"
  end
end

# to test namespacing in a module
class Author
end