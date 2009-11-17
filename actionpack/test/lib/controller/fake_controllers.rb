class << Object; alias_method :const_available?, :const_defined?; end

class ContentController < ActionController::Base; end
class NotAController; end

module Admin
  class << self; alias_method :const_available?, :const_defined?; end
  class NewsFeedController < ActionController::Base; end
  class PostsController < ActionController::Base; end
  class StuffController < ActionController::Base; end
  class UserController < ActionController::Base; end
end

module Api
  class ProductsController < ActionController::Base; end
end

# TODO: Reduce the number of test controllers we use
class AddressesController < ActionController::Base; end
class ArticlesController < ActionController::Base; end
class BarController < ActionController::Base; end
class BooksController < ActionController::Base; end
class BraveController < ActionController::Base; end
class CController < ActionController::Base; end
class ElsewhereController < ActionController::Base; end
class FooController < ActionController::Base; end
class HiController < ActionController::Base; end
class ImageController < ActionController::Base; end
class NotesController < ActionController::Base; end
class PeopleController < ActionController::Base; end
class PostsController < ActionController::Base; end
class SessionsController  < ActionController::Base; end
class StuffController < ActionController::Base; end
class SubpathBooksController < ActionController::Base; end
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
