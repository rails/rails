class MetalB
  def self.call(env)
    [200, { "Content-Type" => "text/html"}, ["Metal B"]]
  end
end
