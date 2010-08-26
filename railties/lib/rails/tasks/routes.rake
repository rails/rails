desc 'Print out all defined routes in match order, with names. Target specific controller with CONTROLLER=x.'
task :routes => :environment do
  Rails.application.reload_routes!

  all_routes   = Rails.application.routes.routes
  named_routes = Rails.application.routes.named_routes.routes

  if ENV['CONTROLLER']
    all_routes = all_routes.select{ |route| route.defaults[:controller] == ENV['CONTROLLER'] }
  end

  routes = all_routes.collect do |route|
    # TODO: The :index method is deprecated in 1.9 in favor of :key
    # but we don't have :key in 1.8.7. We can remove this check when
    # stop supporting 1.8.x
    key  = Hash.method_defined?('key') ? 'key' : 'index'
    name = named_routes.send(key, route).to_s

    reqs = route.requirements.dup
    reqs[:to] = route.app unless route.app.class.name.to_s =~ /^ActionDispatch::Routing/
    reqs = reqs.empty? ? "" : reqs.inspect

    {:name => name, :verb => route.verb.to_s, :path => route.path, :reqs => reqs}
  end

  routes.reject! { |r| r[:path] =~ %r{/rails/info/properties} } # Skip the route if it's internal info route

  name_width = routes.map{ |r| r[:name] }.map(&:length).max
  verb_width = routes.map{ |r| r[:verb] }.map(&:length).max
  path_width = routes.map{ |r| r[:path] }.map(&:length).max

  routes.each do |r|
    puts "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:path].ljust(path_width)} #{r[:reqs]}"
  end
end