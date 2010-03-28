# Allow the metal piece to run in isolation
require File.expand_path('../../../config/environment',  __FILE__) unless defined?(Rails)

class <%= class_name %>
  def self.call(env)
    if env["PATH_INFO"] =~ /^\/<%= file_name %>/
      [200, {"Content-Type" => "text/html"}, ["Hello, World!"]]
    else
      [404, {"Content-Type" => "text/html", "X-Cascade" => "pass"}, ["Not Found"]]
    end
  end
end
