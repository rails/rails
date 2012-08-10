# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

#enable Gzip compression
use Rack::Deflater

run <%= app_const %>
