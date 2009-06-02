class Topic < ActiveRecord::Base
  def condition_is_true
    true
  end

  def condition_is_true_but_its_not
    false
  end
end
