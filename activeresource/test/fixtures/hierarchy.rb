class ParentConnection < ActiveResource::Connection
end

class RootResource < ActiveResource::Base
  self.site = 'http://api.example.com'
end

class ParentResource < RootResource
  self.connection_class = ParentConnection
end

class ChildResource < ParentResource
end
