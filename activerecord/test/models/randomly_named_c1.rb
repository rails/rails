# frozen_string_literal: true

class ClassNameThatDoesNotFollowCONVENTIONS < ActiveRecord::Base
  self.table_name = :randomly_named_table1
end
