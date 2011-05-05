desc 'Print out all defined routes in match order, with names. Target specific controller with CONTROLLER=x.'
task :routes => :environment do
  Rails.application.reload_routes!
  all_routes = Rails.application.routes.routes

  if ENV['CONTROLLER']
    all_routes = all_routes.select{ |route| route.defaults[:controller] == ENV['CONTROLLER'] }
  end

  routes = all_routes.collect do |route|

    reqs = route.requirements.dup
    reqs[:to] = route.app unless route.app.class.name.to_s =~ /^ActionDispatch::Routing/
    reqs = reqs.empty? ? "" : reqs.inspect

    {:name => route.name.to_s, :verb => route.verb.to_s, :path => route.path, :reqs => reqs}
  end

   # Skip the route if it's internal info route
  routes.reject! { |r| r[:path] =~ %r{/rails/info/properties|^/assets} }

  name_width = routes.map{ |r| r[:name].length }.max
  verb_width = routes.map{ |r| r[:verb].length }.max
  path_width = routes.map{ |r| r[:path].length }.max

  routes.each do |r|
    puts "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:path].ljust(path_width)} #{r[:reqs]}"
  end
end
