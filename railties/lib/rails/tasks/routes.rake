desc 'Print out all defined routes in match order, with names. Target specific controller with CONTROLLER=x.'
task :routes => :environment do
  all_routes = ENV['CONTROLLER'] ? ActionController::Routing::Routes.routes.select { |route| route.defaults[:controller] == ENV['CONTROLLER'] } : ActionController::Routing::Routes.routes
  routes = all_routes.collect do |route|
    name = ActionController::Routing::Routes.named_routes.routes.index(route).to_s
    reqs = route.requirements.empty? ? "" : route.requirements.inspect
    {:name => name, :verb => route.verb.to_s, :path => route.path, :reqs => reqs}
  end
  name_width = routes.collect {|r| r[:name]}.collect {|n| n.length}.max
  verb_width = routes.collect {|r| r[:verb]}.collect {|v| v.length}.max
  path_width = routes.collect {|r| r[:path]}.collect {|s| s.length}.max
  routes.each do |r|
    puts "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:path].ljust(path_width)} #{r[:reqs]}"
  end
end
