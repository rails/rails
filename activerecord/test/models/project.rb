class Project < ActiveRecord::Base
  has_and_belongs_to_many :developers, :uniq => true, :order => 'developers.name desc, developers.id desc'
  has_and_belongs_to_many :readonly_developers, :class_name => "Developer", :readonly => true
  has_and_belongs_to_many :selected_developers, :class_name => "Developer", :select => "developers.*", :uniq => true
  has_and_belongs_to_many :non_unique_developers, :order => 'developers.name desc, developers.id desc', :class_name => 'Developer'
  has_and_belongs_to_many :limited_developers, :class_name => "Developer", :limit => 1
  has_and_belongs_to_many :developers_named_david, :class_name => "Developer", :conditions => "name = 'David'", :uniq => true
  has_and_belongs_to_many :developers_named_david_with_hash_conditions, :class_name => "Developer", :conditions => { :name => 'David' }, :uniq => true
  has_and_belongs_to_many :salaried_developers, :class_name => "Developer", :conditions => "salary > 0"
  has_and_belongs_to_many :developers_with_finder_sql, :class_name => "Developer", :finder_sql => 'SELECT t.*, j.* FROM developers_projects j, developers t WHERE t.id = j.developer_id AND j.project_id = #{id} ORDER BY t.id'
  has_and_belongs_to_many :developers_by_sql, :class_name => "Developer", :delete_sql => "DELETE FROM developers_projects WHERE project_id = \#{id} AND developer_id = \#{record.id}"
  has_and_belongs_to_many :developers_with_callbacks, :class_name => "Developer", :before_add => Proc.new {|o, r| o.developers_log << "before_adding#{r.id || '<new>'}"},
                            :after_add => Proc.new {|o, r| o.developers_log << "after_adding#{r.id || '<new>'}"},
                            :before_remove => Proc.new {|o, r| o.developers_log << "before_removing#{r.id}"},
                            :after_remove => Proc.new {|o, r| o.developers_log << "after_removing#{r.id}"}
  has_and_belongs_to_many :well_payed_salary_groups, :class_name => "Developer", :group => "salary", :having => "SUM(salary) > 10000", :select => "SUM(salary) as salary"

  attr_accessor :developers_log

  def after_initialize
    @developers_log = []
  end

end

class SpecialProject < Project
  def hello_world
    "hello there!"
  end
end
