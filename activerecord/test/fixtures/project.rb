class Project < ActiveRecord::Base
  has_and_belongs_to_many :developers, :uniq => true
  has_and_belongs_to_many :developers_named_david, :class_name => "Developer", :conditions => "name = 'David'", :uniq => true
end