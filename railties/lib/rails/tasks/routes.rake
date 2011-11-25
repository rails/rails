desc 'Print out all defined routes in match order, with names. Target specific controller with CONTROLLER=x.'
task :routes => :environment do
  Rails.application.reload_routes!
  all_routes = Rails.application.routes.routes

  require 'rails/application/route_inspector'
  inspector = Rails::Application::RouteInspector.new
  puts inspector.format(all_routes, ENV['CONTROLLER']).join "\n"
end
