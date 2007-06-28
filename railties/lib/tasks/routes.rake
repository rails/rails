desc 'Print out all defined routes in match order, with names.'
task :routes => :environment do
  routes = ActionController::Routing::Routes.routes.collect do |route|
    name = ActionController::Routing::Routes.named_routes.routes.index(route).to_s
    verb = route.conditions[:method].to_s.upcase
    segs = route.segments.inject("") { |str,s| str << s.to_s }
    segs.chop! if segs.length > 1
    reqs = route.requirements.empty? ? "" : route.requirements.inspect
    {:name => name, :verb => verb, :segs => segs, :reqs => reqs}
  end
  name_width = routes.collect {|r| r[:name]}.collect {|n| n.length}.max
  verb_width = routes.collect {|r| r[:verb]}.collect {|v| v.length}.max
  segs_width = routes.collect {|r| r[:segs]}.collect {|s| s.length}.max
  routes.each do |r|
    puts "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:segs].ljust(segs_width)} #{r[:reqs]}"
  end
end