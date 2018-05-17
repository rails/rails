# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/company"
require "models/membership"
require "models/person"
require "models/post"
require "models/project"
require "models/subscriber"
require "models/vegetables"
require "models/shop"
require "models/sponsor"

module InheritanceTestHelper
  def with_store_full_sti_class(&block)
    assign_store_full_sti_class true, &block
  end

  def without_store_full_sti_class(&block)
    assign_store_full_sti_class false, &block
  end

  def assign_store_full_sti_class(flag)
    old_store_full_sti_class = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = flag
    yield
  ensure
    ActiveRecord::Base.store_full_sti_class = old_store_full_sti_class
  end
end

class InheritanceTest < ActiveRecord::TestCase
  include InheritanceTestHelper
  fixtures :companies, :projects, :subscribers, :accounts, :vegetables, :memberships

  def test_class_with_store_full_sti_class_returns_full_name
    with_store_full_sti_class do
      assert_equal "Namespaced::Company", Namespaced::Company.sti_name
    end
  end

  def test_class_with_blank_sti_name
    company = Company.first
    company = company.dup
    company.extend(Module.new {
      def _read_attribute(name)
        return "  " if name == "type"
        super
      end
    })
    company.save!
    company = Company.all.to_a.find { |x| x.id == company.id }
    assert_equal "  ", company.type
  end

  def test_class_without_store_full_sti_class_returns_demodulized_name
    without_store_full_sti_class do
      assert_equal "Company", Namespaced::Company.sti_name
    end
  end

  def test_compute_type_success
    assert_equal Author, Company.send(:compute_type, "Author")
  end

  def test_compute_type_nonexistent_constant
    e = assert_raises NameError do
      Company.send :compute_type, "NonexistentModel"
    end
    assert_equal "uninitialized constant Company::NonexistentModel", e.message
    assert_equal "Company::NonexistentModel", e.name
  end

  def test_compute_type_no_method_error
    ActiveSupport::Dependencies.stub(:safe_constantize, proc { raise NoMethodError }) do
      assert_raises NoMethodError do
        Company.send :compute_type, "InvalidModel"
      end
    end
  end

  def test_compute_type_on_undefined_method
    error = nil
    begin
      Class.new(Author) do
        alias_method :foo, :bar
      end
    rescue => e
      error = e
    end

    ActiveSupport::Dependencies.stub(:safe_constantize, proc { raise e }) do

      exception = assert_raises NameError do
        Company.send :compute_type, "InvalidModel"
      end
      assert_equal error.message, exception.message
    end
  end

  def test_compute_type_argument_error
    ActiveSupport::Dependencies.stub(:safe_constantize, proc { raise ArgumentError }) do
      assert_raises ArgumentError do
        Company.send :compute_type, "InvalidModel"
      end
    end
  end

  def test_should_store_demodulized_class_name_with_store_full_sti_class_option_disabled
    without_store_full_sti_class do
      item = Namespaced::Company.new
      assert_equal "Company", item[:type]
    end
  end

  def test_should_store_full_class_name_with_store_full_sti_class_option_enabled
    with_store_full_sti_class do
      item = Namespaced::Company.new
      assert_equal "Namespaced::Company", item[:type]
    end
  end

  def test_different_namespace_subclass_should_load_correctly_with_store_full_sti_class_option
    with_store_full_sti_class do
      item = Namespaced::Company.create name: "Wolverine 2"
      assert_not_nil Company.find(item.id)
      assert_not_nil Namespaced::Company.find(item.id)
    end
  end

  def test_descends_from_active_record
    assert_not_predicate ActiveRecord::Base, :descends_from_active_record?

    # Abstract subclass of AR::Base.
    assert_predicate LoosePerson, :descends_from_active_record?

    # Concrete subclass of an abstract class.
    assert_predicate LooseDescendant, :descends_from_active_record?

    # Concrete subclass of AR::Base.
    assert_predicate TightPerson, :descends_from_active_record?

    # Concrete subclass of a concrete class but has no type column.
    assert_predicate TightDescendant, :descends_from_active_record?

    # Concrete subclass of AR::Base.
    assert_predicate Post, :descends_from_active_record?

    # Concrete subclasses of a concrete class which has a type column.
    assert_not_predicate StiPost, :descends_from_active_record?
    assert_not_predicate SubStiPost, :descends_from_active_record?

    # Abstract subclass of a concrete class which has a type column.
    # This is pathological, as you'll never have Sub < Abstract < Concrete.
    assert_not_predicate AbstractStiPost, :descends_from_active_record?

    # Concrete subclass of an abstract class which has a type column.
    assert_not_predicate SubAbstractStiPost, :descends_from_active_record?
  end

  def test_company_descends_from_active_record
    assert_not_predicate ActiveRecord::Base, :descends_from_active_record?
    assert AbstractCompany.descends_from_active_record?, "AbstractCompany should descend from ActiveRecord::Base"
    assert Company.descends_from_active_record?, "Company should descend from ActiveRecord::Base"
    assert_not Class.new(Company).descends_from_active_record?, "Company subclass should not descend from ActiveRecord::Base"
  end

  def test_abstract_class
    assert_not_predicate ActiveRecord::Base, :abstract_class?
    assert_predicate LoosePerson, :abstract_class?
    assert_not_predicate LooseDescendant, :abstract_class?
  end

  def test_inheritance_base_class
    assert_equal Post, Post.base_class
    assert_predicate Post, :base_class?
    assert_equal Post, SpecialPost.base_class
    assert_not_predicate SpecialPost, :base_class?
    assert_equal Post, StiPost.base_class
    assert_not_predicate StiPost, :base_class?
    assert_equal Post, SubStiPost.base_class
    assert_not_predicate SubStiPost, :base_class?
    assert_equal SubAbstractStiPost, SubAbstractStiPost.base_class
    assert_predicate SubAbstractStiPost, :base_class?
  end

  def test_abstract_inheritance_base_class
    assert_equal LoosePerson, LoosePerson.base_class
    assert_predicate LoosePerson, :base_class?
    assert_equal LooseDescendant, LooseDescendant.base_class
    assert_predicate LooseDescendant, :base_class?
    assert_equal TightPerson, TightPerson.base_class
    assert_predicate TightPerson, :base_class?
    assert_equal TightPerson, TightDescendant.base_class
    assert_not_predicate TightDescendant, :base_class?
  end

  def test_base_class_activerecord_error
    klass = Class.new { include ActiveRecord::Inheritance }
    assert_raise(ActiveRecord::ActiveRecordError) { klass.base_class }
  end

  def test_a_bad_type_column
    Company.connection.insert "INSERT INTO companies (id, #{QUOTED_TYPE}, name) VALUES(100, 'bad_class!', 'Not happening')"

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

  def test_becomes_and_change_tracking_for_inheritance_columns
    cucumber = Vegetable.find(1)
    cabbage = cucumber.becomes!(Cabbage)
    assert_equal ["Cucumber", "Cabbage"], cabbage.custom_type_change
  end

  def test_alt_becomes_bang_resets_inheritance_type_column
    vegetable = Vegetable.create!(name: "Red Pepper")
    assert_nil vegetable.custom_type

    cabbage = vegetable.becomes!(Cabbage)
    assert_equal "Cabbage", cabbage.custom_type

    vegetable = cabbage.becomes!(Vegetable)
    assert_nil cabbage.custom_type
  end

  def test_inheritance_find_all
    companies = Company.all.merge!(order: "id").to_a
    assert_kind_of Firm, companies[0], "37signals should be a firm"
    assert_kind_of Client, companies[1], "Summit should be a client"
  end

  def test_alt_inheritance_find_all
    companies = Vegetable.all.merge!(order: "id").to_a
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
    cabbage = Cabbage.new(name: "Savoy")
    cabbage.save!

    savoy = Vegetable.find(cabbage.id)
    assert_kind_of Cabbage, savoy
  end

  def test_inheritance_new_with_default_class
    company = Company.new
    assert_equal Company, company.class
  end

  def test_inheritance_new_with_base_class
    company = Company.new(type: "Company")
    assert_equal Company, company.class
  end

  def test_inheritance_new_with_subclass
    firm = Company.new(type: "Firm")
    assert_equal Firm, firm.class
  end

  def test_where_new_with_subclass
    firm = Company.where(type: "Firm").new
    assert_equal Firm, firm.class
  end

  def test_where_create_with_subclass
    firm = Company.where(type: "Firm").create(name: "Basecamp")
    assert_equal Firm, firm.class
  end

  def test_where_create_bang_with_subclass
    firm = Company.where(type: "Firm").create!(name: "Basecamp")
    assert_equal Firm, firm.class
  end

  def test_new_with_abstract_class
    e = assert_raises(NotImplementedError) do
      AbstractCompany.new
    end
    assert_equal("AbstractCompany is an abstract class and cannot be instantiated.", e.message)
  end

  def test_new_with_ar_base
    e = assert_raises(NotImplementedError) do
      ActiveRecord::Base.new
    end
    assert_equal("ActiveRecord::Base is an abstract class and cannot be instantiated.", e.message)
  end

  def test_new_with_invalid_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.new(type: "InvalidType") }
  end

  def test_new_with_unrelated_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.new(type: "Account") }
  end

  def test_where_new_with_invalid_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.where(type: "InvalidType").new }
  end

  def test_where_new_with_unrelated_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.where(type: "Account").new }
  end

  def test_where_create_with_invalid_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.where(type: "InvalidType").create }
  end

  def test_where_create_with_unrelated_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.where(type: "Account").create }
  end

  def test_where_create_bang_with_invalid_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.where(type: "InvalidType").create! }
  end

  def test_where_create_bang_with_unrelated_type
    assert_raise(ActiveRecord::SubclassNotFound) { Company.where(type: "Account").create! }
  end

  def test_new_with_unrelated_namespaced_type
    without_store_full_sti_class do
      e = assert_raises ActiveRecord::SubclassNotFound do
        Namespaced::Company.new(type: "Firm")
      end

      assert_equal "Invalid single-table inheritance type: Namespaced::Firm is not a subclass of Namespaced::Company", e.message
    end
  end

  def test_new_with_complex_inheritance
    assert_nothing_raised { Client.new(type: "VerySpecialClient") }
  end

  def test_new_without_storing_full_sti_class
    without_store_full_sti_class do
      item = Company.new(type: "SpecialCo")
      assert_instance_of Company::SpecialCo, item
    end
  end

  def test_new_with_autoload_paths
    path = File.expand_path("../models/autoloadable", __dir__)
    ActiveSupport::Dependencies.autoload_paths << path

    firm = Company.new(type: "ExtraFirm")
    assert_equal ExtraFirm, firm.class
  ensure
    ActiveSupport::Dependencies.autoload_paths.reject! { |p| p == path }
    ActiveSupport::Dependencies.clear
  end

  def test_inheritance_condition
    assert_equal 11, Company.count
    assert_equal 2, Firm.count
    assert_equal 5, Client.count
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
    assert_equal "37signals", Firm.all.merge!(order: "id").to_a.first.name
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
    assert_kind_of Firm, Company.all.merge!(where: "name = '37signals'").first
    assert_kind_of Firm, Firm.all.merge!(where: "name = '37signals'").first
    assert_nil Client.all.merge!(where: "name = '37signals'").first
  end

  def test_alt_find_first_within_inheritance
    assert_kind_of Cabbage, Vegetable.all.merge!(where: "name = 'his cabbage'").first
    assert_kind_of Cabbage, Cabbage.all.merge!(where: "name = 'his cabbage'").first
    assert_nil Cucumber.all.merge!(where: "name = 'his cabbage'").first
  end

  def test_complex_inheritance
    very_special_client = VerySpecialClient.create("name" => "veryspecial")
    assert_equal very_special_client, VerySpecialClient.where("name = 'veryspecial'").first
    assert_equal very_special_client, SpecialClient.all.merge!(where: "name = 'veryspecial'").first
    assert_equal very_special_client, Company.all.merge!(where: "name = 'veryspecial'").first
    assert_equal very_special_client, Client.all.merge!(where: "name = 'veryspecial'").first
    assert_equal 1, Client.all.merge!(where: "name = 'Summit'").to_a.size
    assert_equal very_special_client, Client.find(very_special_client.id)
  end

  def test_alt_complex_inheritance
    king_cole = KingCole.create("name" => "uniform heads")
    assert_equal king_cole, KingCole.where("name = 'uniform heads'").first
    assert_equal king_cole, GreenCabbage.all.merge!(where: "name = 'uniform heads'").first
    assert_equal king_cole, Cabbage.all.merge!(where: "name = 'uniform heads'").first
    assert_equal king_cole, Vegetable.all.merge!(where: "name = 'uniform heads'").first
    assert_equal 1, Cabbage.all.merge!(where: "name = 'his cabbage'").to_a.size
    assert_equal king_cole, Cabbage.find(king_cole.id)
  end

  def test_eager_load_belongs_to_something_inherited
    account = Account.all.merge!(includes: :firm).find(1)
    assert account.association(:firm).loaded?, "association was not eager loaded"
  end

  def test_alt_eager_loading
    cabbage = RedCabbage.all.merge!(includes: :seller).find(4)
    assert cabbage.association(:seller).loaded?, "association was not eager loaded"
  end

  def test_eager_load_belongs_to_primary_key_quoting
    con = Account.connection
    bind_param = Arel::Nodes::BindParam.new(nil)
    assert_sql(/#{con.quote_table_name('companies')}\.#{con.quote_column_name('id')} = (?:#{Regexp.quote(bind_param.to_sql)}|1)/) do
      Account.all.merge!(includes: :firm).find(1)
    end
  end

  def test_inherits_custom_primary_key
    assert_equal Subscriber.primary_key, SpecialSubscriber.primary_key
  end

  def test_inheritance_without_mapping
    assert_kind_of SpecialSubscriber, SpecialSubscriber.find("webster132")
    assert_nothing_raised { s = SpecialSubscriber.new("name" => "And breaaaaathe!"); s.id = "roger"; s.save }
  end

  def test_scope_inherited_properly
    assert_nothing_raised { Company.of_first_firm }
    assert_nothing_raised { Client.of_first_firm }
  end

  def test_inheritance_with_default_scope
    assert_equal 1, SelectedMembership.count(:all)
  end
end

class InheritanceComputeTypeTest < ActiveRecord::TestCase
  include InheritanceTestHelper
  fixtures :companies

  teardown do
    self.class.const_remove :FirmOnTheFly rescue nil
    Firm.const_remove :FirmOnTheFly rescue nil
  end

  def test_instantiation_doesnt_try_to_require_corresponding_file
    without_store_full_sti_class do
      foo = Firm.first.clone
      foo.type = "FirmOnTheFly"
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

  def test_sti_type_from_attributes_disabled_in_non_sti_class
    phone = Shop::Product::Type.new(name: "Phone")
    product = Shop::Product.new(type: phone)
    assert product.save
  end

  def test_inheritance_new_with_subclass_as_default
    original_type = Company.columns_hash["type"].default
    ActiveRecord::Base.connection.change_column_default :companies, :type, "Firm"
    Company.reset_column_information

    firm = Company.new # without arguments
    assert_equal "Firm", firm.type
    assert_instance_of Firm, firm

    firm = Company.new(firm_name: "Shri Hans Plastic") # with arguments
    assert_equal "Firm", firm.type
    assert_instance_of Firm, firm

    client = Client.new
    assert_equal "Client", client.type
    assert_instance_of Client, client

    firm = Company.new(type: "Client") # overwrite the default type
    assert_equal "Client", firm.type
    assert_instance_of Client, firm
  ensure
    ActiveRecord::Base.connection.change_column_default :companies, :type, original_type
    Company.reset_column_information
  end
end

class InheritanceAttributeTest < ActiveRecord::TestCase
  class Company < ActiveRecord::Base
    self.table_name = "companies"
    attribute :type, :string, default: "InheritanceAttributeTest::Startup"
  end

  class Startup < Company
  end

  class Empire < Company
  end

  def test_inheritance_new_with_subclass_as_default
    startup = Company.new # without arguments
    assert_equal "InheritanceAttributeTest::Startup", startup.type
    assert_instance_of Startup, startup

    empire = Company.new(type: "InheritanceAttributeTest::Empire") # without arguments
    assert_equal "InheritanceAttributeTest::Empire", empire.type
    assert_instance_of Empire, empire
  end
end

class InheritanceAttributeMappingTest < ActiveRecord::TestCase
  setup do
    @old_registry = ActiveRecord::Type.registry
    ActiveRecord::Type.registry = ActiveRecord::Type::AdapterSpecificRegistry.new
    ActiveRecord::Type.register :omg_sti, InheritanceAttributeMappingTest::OmgStiType
    Company.delete_all
    Sponsor.delete_all
  end

  teardown do
    ActiveRecord::Type.registry = @old_registry
  end

  class OmgStiType < ActiveRecord::Type::String
    def cast_value(value)
      if value =~ /\Aomg_(.+)\z/
        $1.classify
      else
        value
      end
    end

    def serialize(value)
      if value
        "omg_%s" % value.underscore
      end
    end
  end

  class Company < ActiveRecord::Base
    self.table_name = "companies"
    attribute :type, :omg_sti
  end

  class Startup < Company; end
  class Empire < Company; end

  class Firm < ActiveRecord::Base
    self.table_name = "companies"

    has_many :sponsors, as: :sponsors
  end

  class Organization < Firm
    self.table_name = "organizations"
  end

  class Sponsor < ActiveRecord::Base
    self.table_name = "sponsors"
    attribute :sponsorable_type, :omg_sti

    belongs_to :sponsorable, polymorphic: true
  end

  def test_polymorphic_type_without_sti
    assert Organization.joins(:sponsors).to_sql.include? "InheritanceAttributeMappingTest::Organization"
  end

  def test_sti_with_custom_type
    Startup.create! name: "a Startup"
    Empire.create! name: "an Empire"

    assert_equal [["a Startup", "omg_inheritance_attribute_mapping_test/startup"],
                  ["an Empire", "omg_inheritance_attribute_mapping_test/empire"]], ActiveRecord::Base.connection.select_rows("SELECT name, type FROM companies").sort
    assert_equal [["a Startup", "InheritanceAttributeMappingTest::Startup"],
                  ["an Empire", "InheritanceAttributeMappingTest::Empire"]], Company.all.map { |a| [a.name, a.type] }.sort

    startup = Startup.first
    startup.becomes! Empire
    startup.save!

    assert_equal [["a Startup", "omg_inheritance_attribute_mapping_test/empire"],
                  ["an Empire", "omg_inheritance_attribute_mapping_test/empire"]], ActiveRecord::Base.connection.select_rows("SELECT name, type FROM companies").sort

    assert_equal [["a Startup", "InheritanceAttributeMappingTest::Empire"],
                  ["an Empire", "InheritanceAttributeMappingTest::Empire"]], Company.all.map { |a| [a.name, a.type] }.sort
  end

  def test_polymorphic_associations_custom_type
    startup = Startup.create! name: "a Startup"
    sponsor = Sponsor.create! sponsorable: startup

    assert_equal ["omg_inheritance_attribute_mapping_test/company"], ActiveRecord::Base.connection.select_values("SELECT sponsorable_type FROM sponsors")

    sponsor = Sponsor.first
    assert_equal startup, sponsor.sponsorable
  end
end
