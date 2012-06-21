require 'cases/helper'
require 'models/topic'
require 'models/reply'

class ScopeOrTest < ActiveRecord::TestCase
  fixtures :topics

  def test_or_includes_union_of_scopes
    scopea = Topic.where(:author_name => 'Carl', :written_on => Date.parse('2006-07-15 14:28:00 UTC'))
    scopeb = Topic.where(:approved => false)
    ored = (scopea.all + scopeb.all).uniq
    assert_equal scopea.or(scopeb).count, ored.size
    scopea.each {|a| assert scopea.or(scopeb).include?(a) }
    scopeb.each {|b| assert scopea.or(scopeb).include?(b) }
  end
end
