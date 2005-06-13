class Project < ActiveRecord::Base
  has_and_belongs_to_many :developers, :uniq => true
  has_and_belongs_to_many :developers_named_david, :class_name => "Developer", :conditions => "name = 'David'", :uniq => true
  has_and_belongs_to_many :salaried_developers, :class_name => "Developer", :conditions => "salary > 0"
  has_and_belongs_to_many :developers_by_sql, :class_name => "Developer", :delete_sql => "DELETE FROM developers_projects WHERE project_id = \#{id} AND developer_id = \#{record.id}"
end

class SpecialProject < Project
  def hello_world
    "hello there!"
  end
end
