class << Object; alias_method :const_available?, :const_defined?; end

class ContentController < ActionController::Base; end

module Admin
  class << self; alias_method :const_available?, :const_defined?; end
  class AccountsController < ActionController::Base; end
  class NewsFeedController < ActionController::Base; end
  class PostsController < ActionController::Base; end
  class StuffController < ActionController::Base; end
  class UserController < ActionController::Base; end
  class UsersController < ActionController::Base; end
end

module Api
  class UsersController < ActionController::Base; end
  class ProductsController < ActionController::Base; end
end

# TODO: Reduce the number of test controllers we use
class AccountController < ActionController::Base; end
class AddressesController < ActionController::Base; end
class ArchiveController < ActionController::Base; end
class ArticlesController < ActionController::Base; end
class BarController < ActionController::Base; end
class BlogController < ActionController::Base; end
class BooksController < ActionController::Base; end
class BraveController < ActionController::Base; end
class CarsController < ActionController::Base; end
class CcController < ActionController::Base; end
class CController < ActionController::Base; end
class ElsewhereController < ActionController::Base; end
class FooController < ActionController::Base; end
class GeocodeController < ActionController::Base; end
class HiController < ActionController::Base; end
class ImageController < ActionController::Base; end
class NewsController < ActionController::Base; end
class NotesController < ActionController::Base; end
class PeopleController < ActionController::Base; end
class PostsController < ActionController::Base; end
class SessionsController  < ActionController::Base; end
class StuffController < ActionController::Base; end
class SubpathBooksController < ActionController::Base; end
class SymbolsController < ActionController::Base; end
class UserController < ActionController::Base; end
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
