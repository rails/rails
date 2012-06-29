desc 'Print out all defined routes in match order, with names. Target specific controller with CONTROLLER=x.'
task :routes => :environment do
  all_routes = Rails.application.routes.routes
  require 'rails/application/routes_inspector'
  inspector = Rails::Application::RoutesInspector.new
  puts inspector.format(all_routes, ENV['CONTROLLER']).join "\n"
end
