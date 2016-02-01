require 'active_support/deprecation'
require 'active_support/core_ext/string/strip' # for strip_heredoc
require 'optparse'

desc 'Print out all defined routes in match order, with names. Target specific controller with --controller option - or its -c shorthand.'
task routes: :environment do
  all_routes = Rails.application.routes.routes
  require 'action_dispatch/routing/inspector'
  inspector = ActionDispatch::Routing::RoutesInspector.new(all_routes)
  if ARGV.any?{ |argv| argv.start_with? 'CONTROLLER' }
    puts <<-eow.strip_heredoc
      Passing `CONTROLLER` to `bin/rake routes` is deprecated and will be removed in Rails 5.1.
      Please use `bin/rake routes -c controller_name` instead.
    eow
  end

  routes_filter = nil
  routes_filter = { controller: ENV['CONTROLLER'] } if ENV['CONTROLLER']

  OptionParser.new do |opts|
    opts.banner = "Usage: rake routes [options]"
    opts.on("-c", "--controller [CONTROLLER]") do |controller|
      routes_filter = { controller: controller }
    end

    opts.on("-g", "--grep [PATTERN]") do |pattern|
      routes_filter = pattern
    end

  end.parse!(ARGV.reject { |x| x == "routes" })

  puts inspector.format(ActionDispatch::Routing::ConsoleFormatter.new, routes_filter)

  exit 0 # ensure extra arguments aren't interpreted as Rake tasks
end
