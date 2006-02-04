class << Object; alias_method :const_available?, :const_defined?; end
  
class ContentController < Class.new(ActionController::Base)
end
class NotAController
end
module Admin
  class << self; alias_method :const_available?, :const_defined?; end
  class UserController < Class.new(ActionController::Base); end
  class NewsFeedController < Class.new(ActionController::Base); end
end

ActionController::Routing::Routes.draw do |map|
  map.route_one 'route_one', :controller => 'elsewhere', :action => 'flash_me'
  map.connect ':controller/:action/:id'
end
