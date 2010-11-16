# Configure Rails Envinronment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

Rails.backtrace_cleaner.remove_silencers!

<% if full? && !options[:skip_active_record] -%>
# Run any available migration from application
ActiveRecord::Migrator.migrate File.expand_path("../dummy/db/migrate/", __FILE__)
<% end -%>

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
