# Load Rails Rakefile extensions
%w(
  annotations
  documentation
  framework
  log
  middleware
  misc
  routes
  tmp
).tap { |arr|
  arr << 'statistics' if Rake.application.current_scope.empty?
}.each do |task|
  load "rails/tasks/#{task}.rake"
end
