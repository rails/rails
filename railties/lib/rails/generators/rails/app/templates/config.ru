# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
# if you want to enable Enable gzip compression, use this line
# use Rack::Deflater
run <%= app_const %>
