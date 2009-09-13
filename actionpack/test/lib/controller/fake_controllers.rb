class << Object; alias_method :const_available?, :const_defined?; end

class ContentController < ActionController::Base
end
class NotAController
end
module Admin
  class << self; alias_method :const_available?, :const_defined?; end
  class UserController < ActionController::Base; end
  class NewsFeedController < ActionController::Base; end
end
class ElsewhereController < ActionController::Base; end
class AddressesController < ActionController::Base; end
class SessionsController  < ActionController::Base; end
class FooController < ActionController::Base; end
class CController < ActionController::Base; end
class HiController < ActionController::Base; end
class BraveController < ActionController::Base; end
class ImageController < ActionController::Base; end
class WeblogController < ActionController::Base; end

# For speed test
class SpeedController < ActionController::Base;  end
class SearchController        < SpeedController; end
class VideosController        < SpeedController; end
class VideoFileController     < SpeedController; end
class VideoSharesController   < SpeedController; end
class VideoAbusesController   < SpeedController; end
class VideoUploadsController  < SpeedController; end
class VideoVisitsController   < SpeedController; end
class UsersController         < SpeedController; end
class SettingsController      < SpeedController; end
class ChannelsController      < SpeedController; end
class ChannelVideosController < SpeedController; end
class LostPasswordsController < SpeedController; end
class PagesController         < SpeedController; end

ActionController::Routing::Routes.draw do |map|
  map.route_one 'route_one', :controller => 'elsewhere', :action => 'flash_me'
  map.connect ':controller/:action/:id'
end
