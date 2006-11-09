require 'abstract_unit'
require 'fixtures/company'
require 'fixtures/project'
require 'fixtures/subscriber'

class InheritanceTest < Test::Unit::TestCase
  fixtures :companies, :projects, :subscribers

  def test_a_bad_type_column
    #SQLServer need to turn Identity Insert On before manually inserting into the Identity column
    if current_adapter?(:SQLServerAdapter, :SybaseAdapter)
      Company.connection.execute "SET IDENTITY_INSERT companies ON"
    end
    Company.connection.insert "INSERT INTO companies (id, #{QUOTED_TYPE}, name) VALUES(100, 'bad_class!', 'Not happening')"

    #We then need to turn it back Off before continuing.
    if current_adapter?(:SQLServerAdapter, :SybaseAdapter)
      Company.connection.execute "SET IDENTITY_INSERT companies OFF"
    end
    assert_raises(ActiveRecord::SubclassNotFound) { Company.find(100) }
  end

  def test_inheritance_find
    assert Company.find(1).kind_of?(Firm), "37signals should be a firm"
    assert Firm.find(1).kind_of?(Firm), "37signals should be a firm"
    assert Company.find(2).kind_of?(Client), "Summit should be a client"
    assert Client.find(2).kind_of?(Client), "Summit should be a client"
  end
  
  def test_alt_inheritance_find
    switch_to_alt_inheritance_column
    test_inheritance_find
    switch_to_default_inheritance_column
  end

  def test_inheritance_find_all
    companies = Company.find(:all, :order => 'id')
    assert companies[0].kind_of?(Firm), "37signals should be a firm"
    assert companies[1].kind_of?(Client), "Summit should be a client"
  end
  
  def test_alt_inheritance_find_all
    switch_to_alt_inheritance_column
    test_inheritance_find_all
    switch_to_default_inheritance_column
  end

  def test_inheritance_save
    firm = Firm.new
    firm.name = "Next Angle"
    firm.save
    
    next_angle = Company.find(firm.id)
    assert next_angle.kind_of?(Firm), "Next Angle should be a firm"
  end
  
  def test_alt_inheritance_save
    switch_to_alt_inheritance_column
    test_inheritance_save
    switch_to_default_inheritance_column
  end

  def test_inheritance_condition
    assert_equal 9, Company.count
    assert_equal 2, Firm.count
    assert_equal 3, Client.count
  end
  
  def test_alt_inheritance_condition
    switch_to_alt_inheritance_column
    test_inheritance_condition
    switch_to_default_inheritance_column
  end

  def test_finding_incorrect_type_data
    assert_raises(ActiveRecord::RecordNotFound) { Firm.find(2) }
    assert_nothing_raised   { Firm.find(1) }
  end
  
  def test_alt_finding_incorrect_type_data
    switch_to_alt_inheritance_column
    test_finding_incorrect_type_data
    switch_to_default_inheritance_column
  end

  def test_update_all_within_inheritance
    Client.update_all "name = 'I am a client'"
    assert_equal "I am a client", Client.find(:all).first.name
    assert_equal "37signals", Firm.find(:all).first.name
  end
  
  def test_alt_update_all_within_inheritance
    switch_to_alt_inheritance_column
    test_update_all_within_inheritance
    switch_to_default_inheritance_column
  end

  def test_destroy_all_within_inheritance
    Client.destroy_all
    assert_equal 0, Client.count
    assert_equal 2, Firm.count
  end
  
  def test_alt_destroy_all_within_inheritance
    switch_to_alt_inheritance_column
    test_destroy_all_within_inheritance
    switch_to_default_inheritance_column
  end

  def test_find_first_within_inheritance
    assert_kind_of Firm, Company.find(:first, :conditions => "name = '37signals'")
    assert_kind_of Firm, Firm.find(:first, :conditions => "name = '37signals'")
    assert_nil Client.find(:first, :conditions => "name = '37signals'")
  end
  
  def test_alt_find_first_within_inheritance
    switch_to_alt_inheritance_column
    test_find_first_within_inheritance
    switch_to_default_inheritance_column
  end

  def test_complex_inheritance
    very_special_client = VerySpecialClient.create("name" => "veryspecial")
    assert_equal very_special_client, VerySpecialClient.find(:first, :conditions => "name = 'veryspecial'")
    assert_equal very_special_client, SpecialClient.find(:first, :conditions => "name = 'veryspecial'")
    assert_equal very_special_client, Company.find(:first, :conditions => "name = 'veryspecial'")
    assert_equal very_special_client, Client.find(:first, :conditions => "name = 'veryspecial'")
    assert_equal 1, Client.find(:all, :conditions => "name = 'Summit'").size
    assert_equal very_special_client, Client.find(very_special_client.id)
  end

  def test_alt_complex_inheritance
    switch_to_alt_inheritance_column
    test_complex_inheritance
    switch_to_default_inheritance_column
  end

  def test_inheritance_without_mapping
    assert_kind_of SpecialSubscriber, SpecialSubscriber.find("webster132")
    assert_nothing_raised { s = SpecialSubscriber.new("name" => "And breaaaaathe!"); s.id = 'roger'; s.save }
  end

  private
    def switch_to_alt_inheritance_column
      # we don't want misleading test results, so get rid of the values in the type column
      Company.find(:all, :order => 'id').each do |c|
        c['type'] = nil
        c.save
      end
      [ Company, Firm, Client].each { |klass| klass.reset_column_information }
      def Company.inheritance_column; @inheritance_column ||= "ruby_type"; end
    end
    def switch_to_default_inheritance_column
      [ Company, Firm, Client].each { |klass| klass.reset_column_information }
    end
end
