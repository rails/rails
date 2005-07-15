module Object::Controllers
  def self.const_available?(*args)
    const_defined?(*args)
  end
  
  class ContentController < ActionController::Base
  end

  module Admin
    def self.const_available?(*args)
      const_defined?(*args)
    end
    
    class UserController < ActionController::Base
    end
    class NewsFeedController < ActionController::Base
    end
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end
