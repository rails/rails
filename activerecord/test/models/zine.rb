class Zine < ActiveRecord::Base
  has_many :interests, :inverse_of => :zine

  def validate_i_am_fun
    !interests.to_a.any?{|i| i.topic =~ /boringz/}
  end
end
