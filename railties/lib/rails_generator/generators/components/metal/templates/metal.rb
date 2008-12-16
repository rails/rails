# Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

class <%= class_name %> < Rails::Rack::Metal
  def call(env)
    if env["PATH_INFO"] =~ /^\/<%= file_name %>/
      [200, {"Content-Type" => "text/html"}, "Hello, World!"]
    else
      super
    end
  end
end
