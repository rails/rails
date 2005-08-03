set :application, "foo"
set :repository, "1/2/#{application}"
set :gateway, "#{__FILE__}.example.com"

role :web, "www.example.com", :primary => true
