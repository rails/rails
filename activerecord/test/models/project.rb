class Project < ActiveRecord::Base
  belongs_to :mentor
  has_and_belongs_to_many :developers, -> { distinct.order "developers.name desc, developers.id desc" }
  has_and_belongs_to_many :readonly_developers, -> { readonly }, :class_name => "Developer"
  has_and_belongs_to_many :non_unique_developers, -> { order "developers.name desc, developers.id desc" }, :class_name => "Developer"
  has_and_belongs_to_many :limited_developers, -> { limit 1 }, :class_name => "Developer"
  has_and_belongs_to_many :developers_named_david, -> { where("name = 'David'").distinct }, :class_name => "Developer"
  has_and_belongs_to_many :developers_named_david_with_hash_conditions, -> { where(:name => "David").distinct }, :class_name => "Developer"
  has_and_belongs_to_many :salaried_developers, -> { where "salary > 0" }, :class_name => "Developer"
  has_and_belongs_to_many :developers_with_callbacks, :class_name => "Developer", :before_add => Proc.new {|o, r| o.developers_log << "before_adding#{r.id || '<new>'}"},
                            :after_add => Proc.new {|o, r| o.developers_log << "after_adding#{r.id || '<new>'}"},
                            :before_remove => Proc.new {|o, r| o.developers_log << "before_removing#{r.id}"},
                            :after_remove => Proc.new {|o, r| o.developers_log << "after_removing#{r.id}"}
  has_and_belongs_to_many :well_payed_salary_groups, -> { group("developers.salary").having("SUM(salary) > 10000").select("SUM(salary) as salary") }, :class_name => "Developer"
  belongs_to :firm
  has_one :lead_developer, through: :firm, inverse_of: :contracted_projects

  begin
    previous_value, ActiveRecord::Base.belongs_to_required_by_default =
      ActiveRecord::Base.belongs_to_required_by_default, true
    has_and_belongs_to_many :developers_required_by_default, class_name: "Developer"
  ensure
    ActiveRecord::Base.belongs_to_required_by_default = previous_value
  end

  attr_accessor :developers_log
  after_initialize :set_developers_log

  def set_developers_log
    @developers_log = []
  end

  def self.all_as_method
    all
  end
  scope :all_as_scope, -> { all }
end

class SpecialProject < Project
end
