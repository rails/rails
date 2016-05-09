require 'rails/dev_caching'

namespace :dev do
  desc 'Toggle development mode caching on/off'
  task :cache do
    Rails::DevCaching.enable_by_file
  end
end
