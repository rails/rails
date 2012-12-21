class Person < ActiveRecord::Base
  has_many :readers
  has_many :secure_readers
  has_one  :reader

  has_many :posts, :through => :readers
  has_many :secure_posts, :through => :secure_readers
  has_many :posts_with_no_comments, :through => :readers, :source => :post, :include => :comments, :conditions => 'comments.id is null'

  has_many :followers, :foreign_key => 'friend_id', :class_name => 'Friendship'

  has_many :references
  has_many :bad_references
  has_many :fixed_bad_references, :conditions => { :favourite => true }, :class_name => 'BadReference'
  has_one  :favourite_reference, :class_name => 'Reference', :conditions => ['favourite=?', true]
  has_many :posts_with_comments_sorted_by_comment_id, :through => :readers, :source => :post, :include => :comments, :order => 'comments.id'

  has_many :jobs, :through => :references
  has_many :jobs_with_dependent_destroy,    :source => :job, :through => :references, :dependent => :destroy
  has_many :jobs_with_dependent_delete_all, :source => :job, :through => :references, :dependent => :delete_all
  has_many :jobs_with_dependent_nullify,    :source => :job, :through => :references, :dependent => :nullify

  belongs_to :primary_contact, :class_name => 'Person'
  has_many :agents, :class_name => 'Person', :foreign_key => 'primary_contact_id'
  has_many :agents_of_agents, :through => :agents, :source => :agents
  belongs_to :number1_fan, :class_name => 'Person'

  has_many :agents_posts,         :through => :agents,       :source => :posts
  has_many :agents_posts_authors, :through => :agents_posts, :source => :author

  scope :males,   :conditions => { :gender => 'M' }
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


class LoosePerson < ActiveRecord::Base
  self.table_name = 'people'
  self.abstract_class = true

  attr_protected :comments, :best_friend_id, :best_friend_of_id
  attr_protected :as => :admin

  has_one    :best_friend,    :class_name => 'LoosePerson', :foreign_key => :best_friend_id
  belongs_to :best_friend_of, :class_name => 'LoosePerson', :foreign_key => :best_friend_of_id
  has_many   :best_friends,   :class_name => 'LoosePerson', :foreign_key => :best_friend_id

  accepts_nested_attributes_for :best_friend, :best_friend_of, :best_friends
end

class LooseDescendant < LoosePerson; end

class TightPerson < ActiveRecord::Base
  self.table_name = 'people'

  attr_accessible :first_name, :gender
  attr_accessible :first_name, :gender, :comments, :as => :admin
  attr_accessible :best_friend_attributes, :best_friend_of_attributes, :best_friends_attributes
  attr_accessible :best_friend_attributes, :best_friend_of_attributes, :best_friends_attributes, :as => :admin

  has_one    :best_friend,    :class_name => 'TightPerson', :foreign_key => :best_friend_id
  belongs_to :best_friend_of, :class_name => 'TightPerson', :foreign_key => :best_friend_of_id
  has_many   :best_friends,   :class_name => 'TightPerson', :foreign_key => :best_friend_id

  accepts_nested_attributes_for :best_friend, :best_friend_of, :best_friends
end

class TightDescendant < TightPerson; end

class RichPerson < ActiveRecord::Base
  self.table_name = 'people'

  has_and_belongs_to_many :treasures, :join_table => 'peoples_treasures'
end

class Insure
  INSURES = %W{life annuality}

  def self.load mask
    INSURES.select do |insure|
      (1 << INSURES.index(insure)) & mask.to_i > 0
    end
  end

  def self.dump insures
    numbers = insures.map { |insure| INSURES.index(insure) }
    numbers.inject(0) { |sum, n| sum + (1 << n) }
  end
end

class SerializedPerson < ActiveRecord::Base
  self.table_name = 'people'

  serialize :insures, Insure
end
