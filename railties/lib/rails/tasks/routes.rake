desc 'Print out all defined routes in match order, with names. Target specific controller with CONTROLLER=x.'
task :routes => :environment do
  Rails.application.reload_routes!
  all_routes = ENV['CONTROLLER'] ? Rails.application.routes.routes.select { |route| route.defaults[:controller] == ENV['CONTROLLER'] } : Rails.application.routes.routes
  routes = all_routes.collect do |route|
    # TODO: The :index method is deprecated in 1.9 in favor of :key
    # but we don't have :key in 1.8.7. We can remove this check when
    # stop supporting 1.8.x
    key_method = Hash.method_defined?('key') ? 'key' : 'index'
    name = Rails.application.routes.named_routes.routes.send(key_method, route).to_s
    reqs = route.requirements.empty? ? "" : route.requirements.inspect
    {:name => name, :verb => route.verb.to_s, :path => route.path, :reqs => reqs}
  end
  routes.reject!{ |r| r[:path] == "/rails/info/properties" } # skip the route if it's internal info route
  name_width = routes.collect {|r| r[:name]}.collect {|n| n.length}.max
  verb_width = routes.collect {|r| r[:verb]}.collect {|v| v.length}.max
  path_width = routes.collect {|r| r[:path]}.collect {|s| s.length}.max
  routes.each do |r|
    puts "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:path].ljust(path_width)} #{r[:reqs]}"
  end
end
