class MetalA
  def self.call(env)
    [404, { "Content-Type" => "text/html"}, ["Metal A"]]
  end
end
