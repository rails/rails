require 'ostruct'

module DeveloperProjectsAssociationExtension
  def find_most_recent
    find(:first, :order => "id DESC")
  end
end

module DeveloperProjectsAssociationExtension2
  def find_least_recent
    find(:first, :order => "id ASC")
  end
end

class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects do
    def find_most_recent
      find(:first, :order => "id DESC")
    end
  end

  has_and_belongs_to_many :projects_extended_by_name,
      :class_name => "Project",
      :join_table => "developers_projects",
      :association_foreign_key => "project_id",
      :extend => DeveloperProjectsAssociationExtension

  has_and_belongs_to_many :projects_extended_by_name_twice,
      :class_name => "Project",
      :join_table => "developers_projects",
      :association_foreign_key => "project_id",
      :extend => [DeveloperProjectsAssociationExtension, DeveloperProjectsAssociationExtension2]

  has_and_belongs_to_many :projects_extended_by_name_and_block,
      :class_name => "Project",
      :join_table => "developers_projects",
      :association_foreign_key => "project_id",
      :extend => DeveloperProjectsAssociationExtension do
        def find_least_recent
          find(:first, :order => "id ASC")
        end
      end

  has_and_belongs_to_many :special_projects, :join_table => 'developers_projects', :association_foreign_key => 'project_id'

  has_many :audit_logs

  scope :jamises, :conditions => {:name => 'Jamis'}

  validates_inclusion_of :salary, :in => 50000..200000
  validates_length_of    :name, :within => 3..20

  before_create do |developer|
    developer.audit_logs.build :message => "Computer created"
  end

  def log=(message)
    audit_logs.build :message => message
  end

  def self.all_johns
    self.with_exclusive_scope :find => where(:name => 'John') do
      self.all
    end
  end

  after_find :track_instance_count
  cattr_accessor :instance_count

  def track_instance_count
    self.class.instance_count ||= 0
    self.class.instance_count += 1
  end
  private :track_instance_count
end

class AuditLog < ActiveRecord::Base
  belongs_to :developer, :validate => true
  belongs_to :unvalidated_developer, :class_name => 'Developer'
end

DeveloperSalary = Struct.new(:amount)
class DeveloperWithAggregate < ActiveRecord::Base
  self.table_name = 'developers'
  composed_of :salary, :class_name => 'DeveloperSalary', :mapping => [%w(salary amount)]
end

class DeveloperWithBeforeDestroyRaise < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :join_table => 'developers_projects', :foreign_key => 'developer_id'
  before_destroy :raise_if_projects_empty!

  def raise_if_projects_empty!
    raise if projects.empty?
  end
end

class DeveloperWithSelect < ActiveRecord::Base
  self.table_name = 'developers'
  default_scope select('name')
end

class DeveloperWithIncludes < ActiveRecord::Base
  self.table_name = 'developers'
  has_many :audit_logs, :foreign_key => :developer_id
  default_scope includes(:audit_logs)
end

class DeveloperOrderedBySalary < ActiveRecord::Base
  self.table_name = 'developers'
  default_scope :order => 'salary DESC'

  scope :by_name, order('name DESC')

  def self.all_ordered_by_name
    with_scope(:find => { :order => 'name DESC' }) do
      find(:all)
    end
  end
end

class DeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'
  default_scope where("name = 'David'")
end

class LazyLambdaDeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'
  default_scope lambda { where(:name => 'David') }
end

class LazyBlockDeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'
  default_scope { where(:name => 'David') }
end

class CallableDeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'
  default_scope OpenStruct.new(:call => where(:name => 'David'))
end

class ClassMethodDeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'

  def self.default_scope
    where(:name => 'David')
  end
end

class ClassMethodReferencingScopeDeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'
  scope :david, where(:name => 'David')

  def self.default_scope
    david
  end
end

class LazyBlockReferencingScopeDeveloperCalledDavid < ActiveRecord::Base
  self.table_name = 'developers'
  scope :david, where(:name => 'David')
  default_scope { david }
end

class DeveloperCalledJamis < ActiveRecord::Base
  self.table_name = 'developers'

  default_scope where(:name => 'Jamis')
  scope :poor, where('salary < 150000')
end

class PoorDeveloperCalledJamis < ActiveRecord::Base
  self.table_name = 'developers'

  default_scope where(:name => 'Jamis', :salary => 50000)
end

class InheritedPoorDeveloperCalledJamis < DeveloperCalledJamis
  self.table_name = 'developers'

  default_scope where(:salary => 50000)
end

class MultiplePoorDeveloperCalledJamis < ActiveRecord::Base
  self.table_name = 'developers'

  default_scope where(:name => 'Jamis')
  default_scope where(:salary => 50000)
end

module SalaryDefaultScope
  extend ActiveSupport::Concern

  included { default_scope where(:salary => 50000) }
end

class ModuleIncludedPoorDeveloperCalledJamis < DeveloperCalledJamis
  self.table_name = 'developers'

  include SalaryDefaultScope
end

class EagerDeveloperWithDefaultScope < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :foreign_key => 'developer_id', :join_table => 'developers_projects', :order => 'projects.id'

  default_scope includes(:projects)
end

class EagerDeveloperWithClassMethodDefaultScope < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :foreign_key => 'developer_id', :join_table => 'developers_projects', :order => 'projects.id'

  def self.default_scope
    includes(:projects)
  end
end

class EagerDeveloperWithLambdaDefaultScope < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :foreign_key => 'developer_id', :join_table => 'developers_projects', :order => 'projects.id'

  default_scope lambda { includes(:projects) }
end

class EagerDeveloperWithBlockDefaultScope < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :foreign_key => 'developer_id', :join_table => 'developers_projects', :order => 'projects.id'

  default_scope { includes(:projects) }
end

class EagerDeveloperWithCallableDefaultScope < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :foreign_key => 'developer_id', :join_table => 'developers_projects', :order => 'projects.id'

  default_scope OpenStruct.new(:call => includes(:projects))
end

class ThreadsafeDeveloper < ActiveRecord::Base
  self.table_name = 'developers'

  def self.default_scope
    sleep 0.05 if Thread.current[:long_default_scope]
    limit(1)
  end
end

class CachedDeveloper < ActiveRecord::Base
  self.table_name = "developers"
  self.cache_timestamp_format = :nsec
end
