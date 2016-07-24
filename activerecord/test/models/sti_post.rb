class StiPost < ActiveRecord::Base
  has_many :sti_comments, :as => :item
  def self.sti_name
    'sti_post'
  end
end
