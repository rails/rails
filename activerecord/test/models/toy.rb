class Toy < ActiveRecord::Base
  set_primary_key :toy_id
  belongs_to :pet

  named_scope :with_name, lambda { |name| {:conditions => {:name => name}} }
end
