require "active_support/testing/autorun"
require "action_controller"
require "action_dispatch"
require "action_system_test"

# Set the Rails tests to use the +:rack_test+ driver because
# we're not testing Capybara or it's drivers, but rather that
# the methods accept the proper arguments.
class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk).build(@routes)
  end

  def call(env)
    @stack.call(env)
  end
end

class ActionSystemTestCase < ActionSystemTest::Base
  ActionSystemTest.driver = :rack_test

  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new)
  end
end

class PostsController < ActionController::Base
  def index
    render inline: <<HTML
<html>
<body>
  <h1>This</h1>
  <p title="the title" class="test">Paragraph 1</p>
  <p title="the others" class="test">Paragraph 2</p>
</body>
</html>
HTML
  end
end

CapybaraRoutes = ActionDispatch::Routing::RouteSet.new
CapybaraRoutes.draw do
  resources :posts
end

# Initialize an application
APP = ActionSystemTestCase.build_app(CapybaraRoutes)

# Initialize an application for Capybara
RailsApp = ActionSystemTestCase.new(APP)

# Assign Capybara.app to original Rack Application
Capybara.app = APP

Capybara.add_selector :title_test do
  xpath { |name| XPath.css(".test")[XPath.attr(:title).is(name.to_s)] }
end

# Skips the current run on Rubinius using Minitest::Assertions#skip
def rubinius_skip(message = "")
  skip message if RUBY_ENGINE == "rbx"
end
# Skips the current run on JRuby using Minitest::Assertions#skip
def jruby_skip(message = "")
  skip message if defined?(JRUBY_VERSION)
end
