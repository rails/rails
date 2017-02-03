require "rake"

# Load Rails Rakefile extensions
%w(
  annotations
  dev
  framework
  initializers
  log
  middleware
  misc
  restart
  routes
  tmp
  yarn
).tap { |arr|
  arr << "statistics" if Rake.application.current_scope.empty?
}.each do |task|
  load "rails/tasks/#{task}.rake"
end
