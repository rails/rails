class AbstractAd < ActiveRecord::Base
  self.abstract_class = true
  table_name
end

class Ad < AbstractAd
end
