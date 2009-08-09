class ProxyResource < ActiveResource::Base
  self.site = "http://localhost"
  self.proxy = "http://user:password@proxy.local:3000"
end