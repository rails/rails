class Person < ActiveRecord::Base
  has_many :readers
  has_one :reader

  has_many :posts, :through => :readers
  has_many :posts_with_no_comments, :through => :readers, :source => :post, :include => :comments, :conditions => 'comments.id is null'

  has_many :references
  has_many :bad_references
  has_many :fixed_bad_references, :conditions => { :favourite => true }, :class_name => 'BadReference'
  has_one :favourite_reference, :class_name => 'Reference', :conditions => ['favourite=?', true]
  has_many :posts_with_comments_sorted_by_comment_id, :through => :readers, :source => :post, :include => :comments, :order => 'comments.id'

  has_many :jobs, :through => :references
  has_many :jobs_with_dependent_destroy, :source => :job, :through => :references, :dependent => :destroy
  has_many :jobs_with_dependent_delete_all, :source => :job, :through => :references, :dependent => :delete_all
  has_many :jobs_with_dependent_nullify, :source => :job, :through => :references, :dependent => :nullify

  belongs_to :primary_contact, :class_name => 'Person'
  has_many :agents, :class_name => 'Person', :foreign_key => 'primary_contact_id'
  has_many :agents_of_agents, :through => :agents, :source => :agents
  belongs_to :number1_fan, :class_name => 'Person'

  scope :males, :conditions => { :gender => 'M' }
  scope :females, :conditions => { :gender => 'F' }
end

class PersonWithDependentDestroyJobs < ActiveRecord::Base
  self.table_name = 'people'

  has_many :references, :foreign_key => :person_id
  has_many :jobs, :source => :job, :through => :references, :dependent => :destroy
end

class PersonWithDependentDeleteAllJobs < ActiveRecord::Base
  self.table_name = 'people'

  has_many :references, :foreign_key => :person_id
  has_many :jobs, :source => :job, :through => :references, :dependent => :delete_all
end

class PersonWithDependentNullifyJobs < ActiveRecord::Base
  self.table_name = 'people'

  has_many :references, :foreign_key => :person_id
  has_many :jobs, :source => :job, :through => :references, :dependent => :nullify
end
