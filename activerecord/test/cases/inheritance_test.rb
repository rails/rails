require "cases/helper"
require 'models/company'
require 'models/person'
require 'models/post'
require 'models/project'
require 'models/subscriber'
require 'models/vegetables'

class InheritanceTest < ActiveRecord::TestCase
  fixtures :companies, :projects, :subscribers, :accounts, :vegetables

  def test_class_with_store_full_sti_class_returns_full_name
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true
    assert_equal 'Namespaced::Company', Namespaced::Company.sti_name
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_class_with_blank_sti_name
    company = Company.first
    company = company.dup
    company.extend(Module.new {
      def read_attribute(name)
        return '  ' if name == 'type'
        super
      end
    })
    company.save!
    company = Company.all.to_a.find { |x| x.id == company.id }
    assert_equal '  ', company.type
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
    assert AbstractCompany.descends_from_active_record?, 'AbstractCompany should descend from ActiveRecord::Base'
    assert Company.descends_from_active_record?, 'Company should descend from ActiveRecord::Base'
    assert !Class.new(Company).descends_from_active_record?, 'Company subclass should not descend from ActiveRecord::Base'
  end

  def test_inheritance_base_class
    assert_equal Post, Post.base_class
    assert_equal Post, SpecialPost.base_class
    assert_equal Post, StiPost.base_class
    assert_equal SubStiPost, SubStiPost.base_class
  end

  def test_abstract_inheritance_base_class
    assert_equal LoosePerson, LoosePerson.base_class
    assert_equal LooseDescendant, LooseDescendant.base_class
    assert_equal TightPerson, TightPerson.base_class
    assert_equal TightPerson, TightDescendant.base_class
  end

  def test_base_class_activerecord_error
    klass = Class.new { include ActiveRecord::Inheritance }
    assert_raise(ActiveRecord::ActiveRecordError) { klass.base_class }
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
    assert_kind_of Firm, Company.find(1), "37signals should be a firm"
    assert_kind_of Firm, Firm.find(1), "37signals should be a firm"
    assert_kind_of Client, Company.find(2), "Summit should be a client"
    assert_kind_of Client, Client.find(2), "Summit should be a client"
  end

  def test_alt_inheritance_find
    assert_kind_of Cucumber, Vegetable.find(1)
    assert_kind_of Cucumber, Cucumber.find(1)
    assert_kind_of Cabbage, Vegetable.find(2)
    assert_kind_of Cabbage, Cabbage.find(2)
  end

  def test_alt_becomes_works_with_sti
    vegetable = Vegetable.find(1)
    assert_kind_of Vegetable, vegetable
    cabbage = vegetable.becomes(Cabbage)
    assert_kind_of Cabbage, cabbage
  end

  def test_inheritance_find_all
    companies = Company.all.merge!(:order => 'id').to_a
    assert_kind_of Firm, companies[0], "37signals should be a firm"
    assert_kind_of Client, companies[1], "Summit should be a client"
  end

  def test_alt_inheritance_find_all
    companies = Vegetable.all.merge!(:order => 'id').to_a
    assert_kind_of Cucumber, companies[0]
    assert_kind_of Cabbage, companies[1]
  end

  def test_inheritance_save
    firm = Firm.new
    firm.name = "Next Angle"
    firm.save

    next_angle = Company.find(firm.id)
    assert_kind_of Firm, next_angle, "Next Angle should be a firm"
  end

  def test_alt_inheritance_save
    cabbage = Cabbage.new(:name => 'Savoy')
    cabbage.save!

    savoy = Vegetable.find(cabbage.id)
    assert_kind_of Cabbage, savoy
  end

  def test_inheritance_new_with_default_class
    company = Company.new
    assert_equal Company, company.class
  end

  def test_inheritance_new_with_base_class
    company = Company.new(:type => 'Company')
    assert_equal Company, company.class
  end

  def test_inheritance_new_with_subclass
    firm = Company.new(:type => 'Firm')
    assert_equal Firm, firm.class
  end

  def test_new_with_invalid_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.new(:type => 'InvalidType') }
  end

  def test_new_with_unrelated_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.new(:type => 'Account') }
  end

  def test_inheritance_condition
    assert_equal 10, Company.count
    assert_equal 2, Firm.count
    assert_equal 4, Client.count
  end

  def test_alt_inheritance_condition
    assert_equal 4, Vegetable.count
    assert_equal 1, Cucumber.count
    assert_equal 3, Cabbage.count
  end

  def test_finding_incorrect_type_data
    assert_raise(ActiveRecord::RecordNotFound) { Firm.find(2) }
    assert_nothing_raised   { Firm.find(1) }
  end

  def test_alt_finding_incorrect_type_data
    assert_raise(ActiveRecord::RecordNotFound) { Cucumber.find(2) }
    assert_nothing_raised   { Cucumber.find(1) }
  end

  def test_update_all_within_inheritance
    Client.update_all "name = 'I am a client'"
    assert_equal "I am a client", Client.first.name
    # Order by added as otherwise Oracle tests were failing because of different order of results
    assert_equal "37signals", Firm.all.merge!(:order => "id").to_a.first.name
  end

  def test_alt_update_all_within_inheritance
    Cabbage.update_all "name = 'the cabbage'"
    assert_equal "the cabbage", Cabbage.first.name
    assert_equal ["my cucumber"], Cucumber.all.map(&:name).uniq
  end

  def test_destroy_all_within_inheritance
    Client.destroy_all
    assert_equal 0, Client.count
    assert_equal 2, Firm.count
  end

  def test_alt_destroy_all_within_inheritance
    Cabbage.destroy_all
    assert_equal 0, Cabbage.count
    assert_equal 1, Cucumber.count
  end

  def test_find_first_within_inheritance
    assert_kind_of Firm, Company.all.merge!(:where => "name = '37signals'").first
    assert_kind_of Firm, Firm.all.merge!(:where => "name = '37signals'").first
    assert_nil Client.all.merge!(:where => "name = '37signals'").first
  end

  def test_alt_find_first_within_inheritance
    assert_kind_of Cabbage, Vegetable.all.merge!(:where => "name = 'his cabbage'").first
    assert_kind_of Cabbage, Cabbage.all.merge!(:where => "name = 'his cabbage'").first
    assert_nil Cucumber.all.merge!(:where => "name = 'his cabbage'").first
  end

  def test_complex_inheritance
    very_special_client = VerySpecialClient.create("name" => "veryspecial")
    assert_equal very_special_client, VerySpecialClient.where("name = 'veryspecial'").first
    assert_equal very_special_client, SpecialClient.all.merge!(:where => "name = 'veryspecial'").first
    assert_equal very_special_client, Company.all.merge!(:where => "name = 'veryspecial'").first
    assert_equal very_special_client, Client.all.merge!(:where => "name = 'veryspecial'").first
    assert_equal 1, Client.all.merge!(:where => "name = 'Summit'").to_a.size
    assert_equal very_special_client, Client.find(very_special_client.id)
  end

  def test_alt_complex_inheritance
    king_cole = KingCole.create("name" => "uniform heads")
    assert_equal king_cole, KingCole.where("name = 'uniform heads'").first
    assert_equal king_cole, GreenCabbage.all.merge!(:where => "name = 'uniform heads'").first
    assert_equal king_cole, Cabbage.all.merge!(:where => "name = 'uniform heads'").first
    assert_equal king_cole, Vegetable.all.merge!(:where => "name = 'uniform heads'").first
    assert_equal 1, Cabbage.all.merge!(:where => "name = 'his cabbage'").to_a.size
    assert_equal king_cole, Cabbage.find(king_cole.id)
  end

  def test_eager_load_belongs_to_something_inherited
    account = Account.all.merge!(:includes => :firm).find(1)
    assert account.association_cache.key?(:firm), "nil proves eager load failed"
  end

  def test_alt_eager_loading
    cabbage = RedCabbage.all.merge!(:includes => :seller).find(4)
    assert cabbage.association_cache.key?(:seller), "nil proves eager load failed"
  end

  def test_eager_load_belongs_to_primary_key_quoting
    con = Account.connection
    assert_sql(/#{con.quote_table_name('companies')}.#{con.quote_column_name('id')} IN \(1\)/) do
      Account.all.merge!(:includes => :firm).find(1)
    end
  end

  def test_inherits_custom_primary_key
    assert_equal Subscriber.primary_key, SpecialSubscriber.primary_key
  end

  def test_inheritance_without_mapping
    assert_kind_of SpecialSubscriber, SpecialSubscriber.find("webster132")
    assert_nothing_raised { s = SpecialSubscriber.new("name" => "And breaaaaathe!"); s.id = 'roger'; s.save }
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
    ActiveRecord::Base.store_full_sti_class = false
    foo = Firm.first.clone
    foo.type = 'FirmOnTheFly'
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
  ensure
    ActiveRecord::Base.store_full_sti_class = true
  end
end
