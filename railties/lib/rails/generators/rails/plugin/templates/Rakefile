begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = '<%= camelized %>'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

<% if engine? && !options[:skip_active_record] && with_dummy_app? -%>
APP_RAKEFILE = File.expand_path("../<%= dummy_path -%>/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'
<% end %>

<% if engine? -%>
load 'rails/tasks/statistics.rake'
<% end %>

<% unless options[:skip_gemspec] -%>

Bundler::GemHelper.install_tasks
<% end %>
