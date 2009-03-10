class EngineMetal
  def self.call(env)
    if env["PATH_INFO"] =~ /^\/metal/
      [200, {"Content-Type" => "text/html"}, ["Engine metal"]]
    else
      [404, {"Content-Type" => "text/html"}, ["Not Found"]]
    end
  end
end

