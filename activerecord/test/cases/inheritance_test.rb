require "cases/helper"
require 'models/company'
require 'models/project'
require 'models/subscriber'

class InheritanceTest < ActiveRecord::TestCase
  fixtures :companies, :projects, :subscribers, :accounts

  def test_class_with_store_full_sti_class_returns_full_name
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true
    assert_equal 'Namespaced::Company', Namespaced::Company.sti_name
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_class_without_store_full_sti_class_returns_demodulized_name
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = false
    assert_equal 'Company', Namespaced::Company.sti_name
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_should_store_demodulized_class_name_with_store_full_sti_class_option_disabled
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = false
    item = Namespaced::Company.new
    assert_equal 'Company', item[:type]
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end
  
  def test_should_store_full_class_name_with_store_full_sti_class_option_enabled
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true
    item = Namespaced::Company.new
    assert_equal 'Namespaced::Company', item[:type]
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end
  
  def test_different_namespace_subclass_should_load_correctly_with_store_full_sti_class_option
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true
    item = Namespaced::Company.create :name => "Wolverine 2"
    assert_not_nil Company.find(item.id)
    assert_not_nil Namespaced::Company.find(item.id)
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_company_descends_from_active_record
    assert_raise(NoMethodError) { ActiveRecord::Base.descends_from_active_record? }
    assert AbstractCompany.descends_from_active_record?, 'AbstractCompany should descend from ActiveRecord::Base'
    assert Company.descends_from_active_record?, 'Company should descend from ActiveRecord::Base'
    assert !Class.new(Company).descends_from_active_record?, 'Company subclass should not descend from ActiveRecord::Base'
  end

  def test_a_bad_type_column
    #SQLServer need to turn Identity Insert On before manually inserting into the Identity column
    if current_adapter?(:SybaseAdapter)
      Company.connection.execute "SET IDENTITY_INSERT companies ON"
    end
    Company.connection.insert "INSERT INTO companies (id, #{QUOTED_TYPE}, name) VALUES(100, 'bad_class!', 'Not happening')"

    #We then need to turn it back Off before continuing.
    if current_adapter?(:SybaseAdapter)
      Company.connection.execute "SET IDENTITY_INSERT companies OFF"
    end
    assert_raise(ActiveRecord::SubclassNotFound) { Company.find(100) }
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
    assert_equal 10, Company.count
    assert_equal 2, Firm.count
    assert_equal 4, Client.count
  end

  def test_alt_inheritance_condition
    switch_to_alt_inheritance_column
    test_inheritance_condition
    switch_to_default_inheritance_column
  end

  def test_finding_incorrect_type_data
    assert_raise(ActiveRecord::RecordNotFound) { Firm.find(2) }
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
    # Order by added as otherwise Oracle tests were failing because of different order of results
    assert_equal "37signals", Firm.find(:all, :order => "id").first.name
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

  def test_eager_load_belongs_to_something_inherited
    account = Account.find(1, :include => :firm)
    assert_not_nil account.instance_variable_get("@firm"), "nil proves eager load failed"
  end

  def test_eager_load_belongs_to_primary_key_quoting
    con = Account.connection
    assert_sql(/\(#{con.quote_table_name('companies')}.#{con.quote_column_name('id')} = 1\)/) do
      Account.find(1, :include => :firm)
    end
  end

  def test_alt_eager_loading
    switch_to_alt_inheritance_column
    test_eager_load_belongs_to_something_inherited
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
      Company.set_inheritance_column('ruby_type')
    end
    def switch_to_default_inheritance_column
      [ Company, Firm, Client].each { |klass| klass.reset_column_information }
      Company.set_inheritance_column('type')
    end
end


class InheritanceComputeTypeTest < ActiveRecord::TestCase
  fixtures :companies

  def setup
    ActiveSupport::Dependencies.log_activity = true
  end

  def teardown
    ActiveSupport::Dependencies.log_activity = false
    self.class.const_remove :FirmOnTheFly rescue nil
    Firm.const_remove :FirmOnTheFly rescue nil
  end

  def test_instantiation_doesnt_try_to_require_corresponding_file
    foo = Firm.find(:first).clone
    foo.ruby_type = foo.type = 'FirmOnTheFly'
    foo.save!

    # Should fail without FirmOnTheFly in the type condition.
    assert_raise(ActiveRecord::RecordNotFound) { Firm.find(foo.id) }

    # Nest FirmOnTheFly in the test case where Dependencies won't see it.
    self.class.const_set :FirmOnTheFly, Class.new(Firm)
    assert_raise(ActiveRecord::SubclassNotFound) { Firm.find(foo.id) }

    # Nest FirmOnTheFly in Firm where Dependencies will see it.
    # This is analogous to nesting models in a migration.
    Firm.const_set :FirmOnTheFly, Class.new(Firm)

    # And instantiate will find the existing constant rather than trying
    # to require firm_on_the_fly.
    assert_nothing_raised { assert_kind_of Firm::FirmOnTheFly, Firm.find(foo.id) }
  end
end
