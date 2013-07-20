class ClassNameThatDoesNotFollowCONVENTIONS < ActiveRecord::Base
  self.table_name = :randomly_named_table
end
