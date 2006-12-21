class BeastResource < ActiveResource::Base
  self.site = 'http://beast.caboo.se'
  site.user = 'foo'
  site.password = 'bar'
end

class Forum < BeastResource
  # taken from BeastResource
  # self.site = 'http://beast.caboo.se'
end

class Topic < BeastResource
  self.site += '/forums/:forum_id'
end
