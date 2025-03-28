class ApplicationRecord < ActiveRecord::Base
  unless ENV["MULTI_DB"]
    primary_abstract_class
  else
    self.abstract_class = true
  end
end
