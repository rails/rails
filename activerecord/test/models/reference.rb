class Reference < ActiveRecord::Base
  belongs_to :person
  belongs_to :job

  has_many :agents_posts_authors, :through => :person
  has_many :legacy_things, as: :resource

  class << self; attr_accessor :make_comments; end
  self.make_comments = false

  def self.polymorphic_name
    'reference'
  end

  before_destroy :make_comments

  def make_comments
    if self.class.make_comments
      person.update comments: "Reference destroyed"
    end
  end
end

class BadReference < ActiveRecord::Base
  self.table_name = 'references'
  default_scope { where(:favourite => false) }
end
