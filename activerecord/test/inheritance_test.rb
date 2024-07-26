require 'abstract_unit'
require 'fixtures/company'


class InheritanceTest < Test::Unit::TestCase
  def setup
    @company_fixtures = create_fixtures "companies"
  end

  def test_inheritance_find
    assert Company.find(1).kind_of?(Firm), "37signals should be a firm"
    assert Firm.find(1).kind_of?(Firm), "37signals should be a firm"
    assert Company.find(2).kind_of?(Client), "Summit should be a client"
    assert Client.find(2).kind_of?(Client), "Summit should be a client"
  end
  
  def test_inheritance_find_all
    companies = Company.find_all(nil, "id")
    assert companies[0].kind_of?(Firm), "37signals should be a firm"
    assert companies[1].kind_of?(Client), "Summit should be a client"
  end
  
  def test_inheritance_save
    firm = Firm.new
    firm.name = "Next Angle"
    firm.save
    
    next_angle = Company.find(firm.id)
    assert next_angle.kind_of?(Firm), "Next Angle should be a firm"
  end
  
  def test_inheritance_condition
    assert_equal 3, Company.find_all.length
    assert_equal 1, Firm.find_all.length
    assert_equal 2, Client.find_all.length
  end
  
  def test_finding_incorrect_type_data
    assert_raises(ActiveRecord::RecordNotFound) { Firm.find(2) }
    assert_nothing_raised   { Firm.find(1) }
  end
  
  def test_update_all_within_inheritance
    Client.update_all "name = 'I am a client'"
    assert_equal "I am a client", Client.find_all.first.name
    assert_equal "37signals", Firm.find_all.first.name
  end
  
  def test_destroy_all_within_inheritance
    Client.destroy_all
    assert_equal 0, Client.find_all.length
    assert_equal 1, Firm.find_all.length
  end
  
  def test_find_first_within_inheritance
    assert_kind_of Firm, Company.find_first("name = '37signals'")
    assert_kind_of Firm, Firm.find_first("name = '37signals'")
    assert_nil Client.find_first("name = '37signals'")
  end
end