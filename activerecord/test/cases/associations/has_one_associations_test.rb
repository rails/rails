# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/project"
require "models/company"
require "models/ship"
require "models/pirate"
require "models/person"
require "models/car"
require "models/bulb"
require "models/author"
require "models/image"
require "models/post"
require "models/drink_designer"
require "models/chef"
require "models/department"
require "models/club"
require "models/membership"
require "models/parrot"
require "models/cpk"
require "models/room"
require "models/user"

class HasOneAssociationsTest < ActiveRecord::TestCase
  self.use_transactional_tests = false unless supports_savepoints?
  fixtures :accounts, :companies, :developers, :projects, :developers_projects,
           :ships, :pirates, :authors, :author_addresses, :books, :memberships, :clubs

  def setup
    Account.destroyed_account_ids.clear
  end

  def test_has_one
    firm = companies(:first_firm)
    first_account = Account.find(1)
    assert_queries_match(/LIMIT|ROWNUM <=|FETCH FIRST/) do
      assert_equal first_account, firm.account
      assert_equal first_account.credit_limit, firm.account.credit_limit
    end
  end

  def test_has_one_does_not_use_order_by
    sql_log = capture_sql { companies(:first_firm).account }
    assert sql_log.all? { |sql| !/order by/i.match?(sql) }, "ORDER BY was used in the query: #{sql_log}"
  end

  def test_has_one_cache_nils
    firm = companies(:another_firm)
    assert_queries_count(1) { assert_nil firm.account }
    assert_no_queries { assert_nil firm.account }

    firms = Firm.includes(:account).to_a
    assert_no_queries { firms.each(&:account) }
  end

  def test_with_select
    assert_equal 2, Firm.find(1).account_with_select.attributes.size
    assert_equal 2, Firm.all.merge!(includes: :account_with_select).find(1).account_with_select.attributes.size
  end

  def test_finding_using_primary_key
    firm = companies(:first_firm)
    assert_equal Account.find_by_firm_id(firm.id), firm.account
    firm.firm_id = companies(:rails_core).id
    assert_equal accounts(:rails_core_account), firm.account_using_primary_key
  end

  def test_update_with_foreign_and_primary_keys
    firm = companies(:first_firm)
    account = firm.account_using_foreign_and_primary_keys
    assert_equal Account.find_by_firm_name(firm.name), account
    firm.save
    firm.reload
    assert_equal account, firm.account_using_foreign_and_primary_keys
  end

  def test_can_marshal_has_one_association_with_nil_target
    firm = Firm.new
    assert_nothing_raised do
      assert_equal firm.attributes, Marshal.load(Marshal.dump(firm)).attributes
    end

    firm.account
    assert_nothing_raised do
      assert_equal firm.attributes, Marshal.load(Marshal.dump(firm)).attributes
    end
  end

  def test_proxy_assignment
    company = companies(:first_firm)
    assert_nothing_raised { company.account = company.account }
  end

  def test_type_mismatch
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).account = 1 }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).account = Project.find(1) }
  end

  def test_natural_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_to_nil
    old_account_id = companies(:first_firm).account.id
    companies(:first_firm).account = nil
    companies(:first_firm).save
    assert_nil companies(:first_firm).account
    # account is dependent, therefore is destroyed when reference to owner is lost
    assert_raise(ActiveRecord::RecordNotFound) { Account.find(old_account_id) }
  end

  def test_nullification_on_association_change
    firm = companies(:rails_core)
    old_account_id = firm.account.id
    firm.account = Account.new(credit_limit: 5)
    # account is dependent with nullify, therefore its firm_id should be nil
    assert_nil Account.find(old_account_id).firm_id
  end

  def test_nullify_on_polymorphic_association
    department = Department.create!
    designer = DrinkDesignerWithPolymorphicDependentNullifyChef.create!
    chef = department.chefs.create!(employable: designer)

    assert_equal chef.employable_id, designer.id
    assert_equal chef.employable_type, designer.class.name

    designer.destroy!
    chef.reload

    assert_nil chef.employable_id
    assert_nil chef.employable_type
  end

  def test_nullification_on_destroyed_association
    developer = Developer.create!(name: "Someone")
    ship = Ship.create!(name: "Planet Caravan", developer: developer)
    ship.destroy
    assert_not_predicate ship, :persisted?
    assert_not_predicate developer, :persisted?
  end

  def test_nullification_on_cpk_association
    book = Cpk::Book.create!(id: [1, 2])
    other_book = Cpk::Book.create!(id: [3, 4])
    order = Cpk::OrderWithNullifiedBook.create!(book: book)

    order.book = other_book

    assert_nil book.order_id
    assert_nil book.shop_id
  end

  def test_natural_assignment_to_nil_after_destroy
    firm = companies(:rails_core)
    old_account_id = firm.account.id
    firm.account.destroy
    firm.account = nil
    assert_nil companies(:rails_core).account
    assert_raise(ActiveRecord::RecordNotFound) { Account.find(old_account_id) }
  end

  def test_association_change_calls_delete
    companies(:first_firm).deletable_account = Account.new(credit_limit: 5)
    assert_equal [], Account.destroyed_account_ids[companies(:first_firm).id]
  end

  def test_association_change_calls_destroy
    companies(:first_firm).account = Account.new(credit_limit: 5)
    assert_equal [companies(:first_firm).id], Account.destroyed_account_ids[companies(:first_firm).id]
  end

  def test_natural_assignment_to_already_associated_record
    company = companies(:first_firm)
    account = accounts(:signals37)
    assert_equal company.account, account
    company.account = account
    company.reload
    account.reload
    assert_equal company.account, account
  end

  def test_dependence
    num_accounts = Account.count

    firm = Firm.find(1)
    assert_not_nil firm.account
    account_id = firm.account.id
    assert_equal [], Account.destroyed_account_ids[firm.id]

    firm.destroy
    assert_equal num_accounts - 1, Account.count
    assert_equal [account_id], Account.destroyed_account_ids[firm.id]
  end

  def test_exclusive_dependence
    num_accounts = Account.count

    firm = ExclusivelyDependentFirm.find(9)
    assert_not_nil firm.account
    assert_equal [], Account.destroyed_account_ids[firm.id]

    firm.destroy
    assert_equal num_accounts - 1, Account.count
    assert_equal [], Account.destroyed_account_ids[firm.id]
  end

  def test_dependence_with_nil_associate
    firm = DependentFirm.new(name: "nullify")
    firm.save!
    assert_nothing_raised { firm.destroy }
  end

  def test_restrict_with_exception
    firm = RestrictedWithExceptionFirm.create!(name: "restrict")
    firm.create_account(credit_limit: 10)

    assert_not_nil firm.account

    assert_raise(ActiveRecord::DeleteRestrictionError) { firm.destroy }
    assert RestrictedWithExceptionFirm.exists?(name: "restrict")
    assert_predicate firm.account, :present?
  end

  def test_restrict_with_error
    firm = RestrictedWithErrorFirm.create!(name: "restrict")
    firm.create_account(credit_limit: 10)

    assert_not_nil firm.account

    firm.destroy

    assert_not_empty firm.errors
    assert_equal "Cannot delete record because a dependent account exists", firm.errors[:base].first
    assert RestrictedWithErrorFirm.exists?(name: "restrict")
    assert_predicate firm.account, :present?
  end

  def test_restrict_with_error_with_locale
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations "en", activerecord: { attributes: { restricted_with_error_firm: { account: "firm account" } } }
    firm = RestrictedWithErrorFirm.create!(name: "restrict")
    firm.create_account(credit_limit: 10)

    assert_not_nil firm.account

    firm.destroy

    assert_not_empty firm.errors
    assert_equal "Cannot delete record because a dependent firm account exists", firm.errors[:base].first
    assert RestrictedWithErrorFirm.exists?(name: "restrict")
    assert_predicate firm.account, :present?
  ensure
    I18n.backend.reload!
  end

  def test_successful_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    account = firm.build_account("credit_limit" => 1000)
    assert account.save
    assert_equal account, firm.account
  end

  def test_build_association_dont_create_transaction
    firm = Firm.new
    assert_queries_count(0) do
      firm.build_account
    end
  end

  def test_building_the_associated_object_with_implicit_sti_base_class
    firm = DependentFirm.new
    company = firm.build_company
    assert_kind_of Company, company, "Expected #{company.class} to be a Company"
  end

  def test_building_the_associated_object_with_explicit_sti_base_class
    firm = DependentFirm.new
    company = firm.build_company(type: "Company")
    assert_kind_of Company, company, "Expected #{company.class} to be a Company"
  end

  def test_building_the_associated_object_with_sti_subclass
    firm = DependentFirm.new
    company = firm.build_company(type: "Client")
    assert_kind_of Client, company, "Expected #{company.class} to be a Client"
  end

  def test_building_the_associated_object_with_an_invalid_type
    firm = DependentFirm.new
    assert_raise(ActiveRecord::SubclassNotFound) { firm.build_company(type: "Invalid") }
  end

  def test_building_the_associated_object_with_an_unrelated_type
    firm = DependentFirm.new
    assert_raise(ActiveRecord::SubclassNotFound) { firm.build_company(type: "Account") }
  end

  def test_build_and_create_should_not_happen_within_scope
    pirate = pirates(:blackbeard)
    scope = pirate.association(:foo_bulb).scope.where_values_hash

    bulb = pirate.build_foo_bulb
    assert_not_equal scope, bulb.scope_after_initialize.where_values_hash

    bulb = pirate.create_foo_bulb
    assert_not_equal scope, bulb.scope_after_initialize.where_values_hash

    bulb = pirate.create_foo_bulb!
    assert_not_equal scope, bulb.scope_after_initialize.where_values_hash
  end

  def test_create_association
    firm = Firm.create(name: "GlobalMegaCorp")
    account = firm.create_account(credit_limit: 1000)
    assert_equal account, firm.reload.account
  end

  def test_clearing_an_association_clears_the_associations_inverse
    author = Author.create(name: "Jimmy Tolkien")
    post = author.create_post(title: "The silly medallion", body: "")
    assert_equal post, author.post
    assert_equal author, post.author

    post.update!(author: nil)
    assert_nil post.author

    author.update!(name: "J.R.R. Tolkien")
    assert_nil post.author
  end

  def test_create_association_with_bang
    firm = Firm.create(name: "GlobalMegaCorp")
    account = firm.create_account!(credit_limit: 1000)
    assert_equal account, firm.reload.account
  end

  def test_create_association_with_bang_failing
    firm = Firm.create(name: "GlobalMegaCorp")
    assert_raise ActiveRecord::RecordInvalid do
      firm.create_account!
    end
    account = firm.account
    assert_not_nil account
    account.credit_limit = 5
    account.save
    assert_equal account, firm.reload.account
  end

  def test_create_with_inexistent_foreign_key_failing
    firm = Firm.create(name: "GlobalMegaCorp")

    assert_raises(ActiveRecord::UnknownAttributeError) do
      firm.create_account_with_inexistent_foreign_key
    end
  end

  def test_create_when_parent_is_new_raises
    firm = Firm.new
    error = assert_raise(ActiveRecord::RecordNotSaved) do
      firm.create_account
    end

    assert_equal "You cannot call create unless the parent is saved", error.message
    assert_equal firm, error.record
  end

  def test_reload_association
    odegy = companies(:odegy)

    assert_equal 53, odegy.account.credit_limit
    Account.where(id: odegy.account.id).update_all(credit_limit: 80)
    assert_equal 53, odegy.account.credit_limit

    assert_queries_count(1) { odegy.reload_account }
    assert_no_queries { odegy.account }
    assert_equal 80, odegy.account.credit_limit
  end

  def test_reload_association_with_query_cache
    odegy_id = companies(:odegy).id

    connection = ActiveRecord::Base.lease_connection
    connection.enable_query_cache!
    connection.clear_query_cache

    # Populate the cache with a query
    odegy = Company.find(odegy_id)
    # Populate the cache with a second query
    odegy.account

    assert_equal 2, connection.query_cache.size

    # Clear the cache and fetch the account again, populating the cache with a query
    assert_queries_count(1) { odegy.reload_account }

    # This query is not cached anymore, so it should make a real SQL query
    assert_queries_count(1) { Company.find(odegy_id) }
  ensure
    ActiveRecord::Base.lease_connection.disable_query_cache!
  end

  def test_reset_association
    odegy = companies(:odegy)

    assert_equal 53, odegy.account.credit_limit
    Account.where(id: odegy.account.id).update_all(credit_limit: 80)
    assert_equal 53, odegy.account.credit_limit

    assert_no_queries { odegy.reset_account }

    assert_queries_count(1) { odegy.account }
    assert_equal 80, odegy.account.credit_limit
  end

  def test_build
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.save
    assert_equal account, firm.account
  end

  def test_create
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    firm.account = account = Account.create("credit_limit" => 1000)
    assert_equal account, firm.account
  end

  def test_create_before_save
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = account = Account.create("credit_limit" => 1000)
    assert_equal account, firm.account
  end

  def test_dependence_with_missing_association
    Account.destroy_all
    firm = Firm.find(1)
    assert_nil firm.account
    firm.destroy
  end

  def test_dependence_with_missing_association_and_nullify
    Account.destroy_all
    firm = DependentFirm.first
    assert_nil firm.account
    firm.destroy
  end

  def test_finding_with_interpolated_condition
    firm = Firm.first
    superior = firm.clients.create(name: "SuperiorCo")
    superior.rating = 10
    superior.save
    assert_equal 10, firm.clients_with_interpolated_conditions.first.rating
  end

  def test_assignment_before_child_saved
    firm = Firm.find(1)
    firm.account = a = Account.new("credit_limit" => 1000)
    assert_predicate a, :persisted?
    assert_equal a, firm.account
    assert_equal a, firm.account
    firm.association(:account).reload
    assert_equal a, firm.account
  end

  def test_save_still_works_after_accessing_nil_has_one
    jp = Company.new name: "Jaded Pixel"
    jp.dummy_account.nil?

    assert_nothing_raised do
      jp.save!
    end
  end

  def test_cant_save_readonly_association
    assert_raise(ActiveRecord::ReadOnlyRecord) { companies(:first_firm).readonly_account.save!  }
    assert_predicate companies(:first_firm).readonly_account, :readonly?
  end

  def test_has_one_proxy_should_not_respond_to_private_methods
    assert_raise(NoMethodError) { accounts(:signals37).private_method }
    assert_raise(NoMethodError) { companies(:first_firm).account.private_method }
  end

  def test_has_one_proxy_should_respond_to_private_methods_via_send
    assert_nothing_raised do
      accounts(:signals37).send(:private_method)
      companies(:first_firm).account.send(:private_method)
    end
  end

  def test_save_of_record_with_loaded_has_one
    @firm = companies(:first_firm)
    assert_not_nil @firm.account

    assert_nothing_raised do
      Firm.find(@firm.id).save!
      Firm.all.merge!(includes: :account).find(@firm.id).save!
    end

    @firm.account.destroy

    assert_nothing_raised do
      Firm.find(@firm.id).save!
      Firm.all.merge!(includes: :account).find(@firm.id).save!
    end
  end

  def test_build_respects_hash_condition
    account = companies(:first_firm).build_account_limit_500_with_hash_conditions
    assert account.save
    assert_equal 500, account.credit_limit
  end

  def test_create_respects_hash_condition
    account = companies(:first_firm).create_account_limit_500_with_hash_conditions
    assert_predicate account, :persisted?
    assert_equal 500, account.credit_limit
  end

  def test_attributes_are_being_set_when_initialized_from_has_one_association_with_where_clause
    new_account = companies(:first_firm).build_account(firm_name: "Account")
    assert_equal "Account", new_account.firm_name
  end

  def test_creation_failure_replaces_existing_without_dependent_option
    pirate = pirates(:blackbeard)
    orig_ship = pirate.ship

    assert_equal ships(:black_pearl), orig_ship
    new_ship = pirate.create_ship
    assert_not_equal ships(:black_pearl), new_ship
    assert_equal new_ship, pirate.ship
    assert_predicate new_ship, :new_record?
    assert_predicate new_ship, :invalid?
    assert_nil orig_ship.pirate_id
    assert_not orig_ship.changed? # check it was saved
  end

  def test_creation_failure_replaces_existing_with_dependent_option
    pirate = pirates(:blackbeard).becomes(DestructivePirate)
    orig_ship = pirate.dependent_ship

    new_ship = pirate.create_dependent_ship
    assert_predicate new_ship, :new_record?
    assert_predicate new_ship, :invalid?
    assert_predicate orig_ship, :destroyed?
  end

  def test_creation_failure_due_to_new_record_should_raise_error
    pirate = pirates(:redbeard)
    new_ship = Ship.new

    error = assert_raise(ActiveRecord::RecordNotSaved) do
      pirate.ship = new_ship
    end

    assert_equal "Failed to save the new associated ship.", error.message
    assert_equal new_ship, error.record
    assert_nil pirate.ship
    assert_nil new_ship.pirate_id
  end

  def test_replacement_failure_due_to_existing_record_should_raise_error
    pirate = pirates(:blackbeard)
    pirate.ship.name = nil

    assert_not_predicate pirate.ship, :valid?
    error = assert_raise(ActiveRecord::RecordNotSaved) do
      pirate.ship = ships(:interceptor)
    end

    assert_equal ships(:black_pearl), pirate.ship
    assert_equal pirate.id, pirate.ship.pirate_id
    assert_equal "Failed to remove the existing associated ship. " \
                 "The record failed to save after its foreign key was set to nil.", error.message
    assert_equal pirate.ship, error.record
  end

  def test_replacement_failure_due_to_new_record_should_raise_error
    pirate = pirates(:blackbeard)
    new_ship = Ship.new

    error = assert_raise(ActiveRecord::RecordNotSaved) do
      pirate.ship = new_ship
    end

    assert_equal "Failed to save the new associated ship.", error.message
    assert_equal new_ship, error.record
    assert_equal ships(:black_pearl), pirate.ship
    assert_equal pirate.id, pirate.ship.pirate_id
    assert_equal pirate.id, ships(:black_pearl).reload.pirate_id
    assert_nil new_ship.pirate_id
  end

  def test_association_keys_bypass_attribute_protection
    car = Car.create(name: "honda")

    bulb = car.build_bulb
    assert_equal car.id, bulb.car_id

    bulb = car.build_bulb car_id: car.id + 1
    assert_equal car.id, bulb.car_id

    bulb = car.create_bulb
    assert_equal car.id, bulb.car_id

    bulb = car.create_bulb car_id: car.id + 1
    assert_equal car.id, bulb.car_id
  end

  def test_association_protect_foreign_key
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")

    ship = pirate.build_ship
    assert_equal pirate.id, ship.pirate_id

    ship = pirate.build_ship pirate_id: pirate.id + 1
    assert_equal pirate.id, ship.pirate_id

    ship = pirate.create_ship
    assert_equal pirate.id, ship.pirate_id

    ship = pirate.create_ship pirate_id: pirate.id + 1
    assert_equal pirate.id, ship.pirate_id
  end

  def test_build_with_block
    car = Car.create(name: "honda")

    bulb = car.build_bulb { |b| b.color = "Red" }
    assert_equal "RED!", bulb.color
  end

  def test_create_with_block
    car = Car.create(name: "honda")

    bulb = car.create_bulb { |b| b.color = "Red" }
    assert_equal "RED!", bulb.color
  end

  def test_create_bang_with_block
    car = Car.create(name: "honda")

    bulb = car.create_bulb! { |b| b.color = "Red" }
    assert_equal "RED!", bulb.color
  end

  def test_association_attributes_are_available_to_after_initialize
    car = Car.create(name: "honda")
    bulb = car.create_bulb

    assert_equal car.id, bulb.attributes_after_initialize["car_id"]
  end

  def test_has_one_transaction
    company = companies(:first_firm)
    account = Account.find(1)

    company.account # force loading
    assert_no_queries { company.account = account }

    company.account = nil
    assert_no_queries { company.account = nil }
    account = Account.find(2)
    assert_queries_count(3) { company.account = account }

    assert_no_queries { Firm.new.account = account }
  end

  def test_has_one_assignment_dont_trigger_save_on_change_of_same_object
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    ship = pirate.build_ship(name: "old name")
    ship.save!

    ship.name = "new name"
    assert_predicate ship, :changed?
    assert_queries_count(3) do
      # One query for updating name, not triggering query for updating pirate_id
      pirate.ship = ship
    end

    assert_equal "new name", pirate.ship.reload.name
  end

  def test_has_one_assignment_triggers_save_on_change_on_replacing_object
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    ship = pirate.build_ship(name: "old name")
    ship.save!

    new_ship = Ship.create(name: "new name")
    assert_queries_count(4) do
      # One query to nullify the old ship, one query to update the new ship
      pirate.ship = new_ship
    end

    assert_equal "new name", pirate.ship.reload.name
  end

  def test_has_one_autosave_with_primary_key_manually_set
    post = Post.create(id: 1234, title: "Some title", body: "Some content")
    author = Author.new(id: 33, name: "Hank Moody")

    author.post = post
    author.save
    author.reload

    assert_not_nil author.post
    assert_equal author.post, post
  end

  def test_has_one_loading_for_new_record
    post = Post.create!(author_id: 42, title: "foo", body: "bar")
    author = Author.new(id: 42)
    assert_equal post, author.post
  end

  def test_has_one_relationship_cannot_have_a_counter_cache
    assert_raise(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        has_one :thing, counter_cache: true
      end
    end
  end

  def test_with_polymorphic_has_one_with_custom_columns_name
    post = Post.create! title: "foo", body: "bar"
    image = Image.create!

    post.main_image = image
    post.reload

    assert_equal image, post.main_image
    assert_equal post, image.imageable
  end

  test "dangerous association name raises ArgumentError" do
    [:errors, "errors", :save, "save"].each do |name|
      assert_raises(ArgumentError, "Association #{name} should not be allowed") do
        Class.new(ActiveRecord::Base) do
          has_one name
        end
      end
    end
  end

  def test_has_one_with_touch_option_on_create
    assert_queries_count(5) {
      Club.create(name: "1000 Oaks", membership_attributes: { favorite: true })
    }
  end

  def test_polymorphic_has_one_with_touch_option_on_create_wont_cache_association_so_fetching_after_transaction_commit_works
    assert_queries_count(6) {
      chef = Chef.create(employable: DrinkDesignerWithPolymorphicTouchChef.new)
      employable = chef.employable

      assert_equal chef, employable.chef
    }
  end

  def test_polymorphic_has_one_with_touch_option_on_update_will_touch_record_by_fetching_from_database_if_needed
    DrinkDesignerWithPolymorphicTouchChef.create(chef: Chef.new)
    designer = DrinkDesignerWithPolymorphicTouchChef.last

    assert_queries_count(5) {
      designer.update(name: "foo")
    }
  end

  def test_has_one_with_touch_option_on_update
    new_club = Club.create(name: "1000 Oaks")
    new_club.create_membership

    assert_queries_count(4) { new_club.update(name: "Effingut") }
  end

  def test_has_one_with_touch_option_on_touch
    new_club = Club.create(name: "1000 Oaks")
    new_club.create_membership

    assert_queries_count(3) { new_club.touch }
  end

  def test_has_one_with_touch_option_on_destroy
    new_club = Club.create(name: "1000 Oaks")
    new_club.create_membership

    assert_queries_count(4) { new_club.destroy }
  end

  def test_has_one_with_touch_option_on_empty_update
    new_club = Club.create(name: "1000 Oaks")
    new_club.create_membership

    assert_no_queries { new_club.save }
  end

  def test_has_one_double_belongs_to_destroys_both_from_either_end
    landlord = User.create!
    tenant = User.create!
    room = Room.create!(landlord: landlord, tenant: tenant)

    landlord.destroy!

    assert_predicate(room, :destroyed?)
    assert_predicate(landlord, :destroyed?)
    assert_predicate(tenant, :destroyed?)

    landlord = User.create!
    tenant = User.create!
    room = Room.create!(landlord: landlord, tenant: tenant)

    tenant.destroy!

    assert_predicate(room, :destroyed?)
    assert_predicate(tenant, :destroyed?)
    assert_predicate(landlord, :destroyed?)
  end

  class SpecialBook < ActiveRecord::Base
    self.table_name = "books"
    belongs_to :author, class_name: "SpecialAuthor"
    has_one :subscription, class_name: "SpecialSubscription", foreign_key: "subscriber_id"

    enum :status, [:proposed, :written, :published]
  end

  class SpecialAuthor < ActiveRecord::Base
    self.table_name = "authors"
    has_one :book, class_name: "SpecialBook", foreign_key: "author_id"
  end

  class SpecialSubscription < ActiveRecord::Base
    self.table_name = "subscriptions"
    belongs_to :book, class_name: "SpecialBook"
  end

  def test_association_enum_works_properly
    author = SpecialAuthor.create!(name: "Test")
    book = SpecialBook.create!(status: "published")
    author.book = book

    assert_equal "published", book.status
    assert_not_equal 0, SpecialAuthor.joins(:book).where(books: { status: "published" }).count
  end

  def test_association_enum_works_properly_with_nested_join
    author = SpecialAuthor.create!(name: "Test")
    book = SpecialBook.create!(status: "published")
    author.book = book

    where_clause = { books: { subscriptions: { subscriber_id: nil } } }
    assert_nothing_raised do
      SpecialAuthor.joins(book: :subscription).where.not(where_clause)
    end
  end

  class DestroyByParentBook < ActiveRecord::Base
    self.table_name = "books"
    belongs_to :author, class_name: "DestroyByParentAuthor"
    before_destroy :dont, unless: :destroyed_by_association

    def dont
      throw(:abort)
    end
  end

  class DestroyByParentAuthor < ActiveRecord::Base
    self.table_name = "authors"
    has_one :book, class_name: "DestroyByParentBook", foreign_key: "author_id", dependent: :destroy
  end

  test "destroyed_by_association set in child destroy callback on parent destroy" do
    author = DestroyByParentAuthor.create!(name: "Test")
    book = DestroyByParentBook.create!(author: author)

    author.destroy

    assert_not DestroyByParentBook.exists?(book.id)
  end

  test "destroyed_by_association set in child destroy callback on replace" do
    author = DestroyByParentAuthor.create!(name: "Test")
    book = DestroyByParentBook.create!(author: author)

    author.book = DestroyByParentBook.create!
    author.save!

    assert_not DestroyByParentBook.exists?(book.id)
  end

  class UndestroyableBook < ActiveRecord::Base
    self.table_name = "books"
    belongs_to :author, class_name: "DestroyableAuthor"
    before_destroy :dont

    def dont
      throw(:abort)
    end
  end

  class DestroyableAuthor < ActiveRecord::Base
    self.table_name = "authors"
    has_one :book, class_name: "UndestroyableBook", foreign_key: "author_id", dependent: :destroy
  end

  def test_dependency_should_halt_parent_destruction
    author = DestroyableAuthor.create!(name: "Test")
    UndestroyableBook.create!(author: author)

    assert_no_difference ["DestroyableAuthor.count", "UndestroyableBook.count"] do
      assert_not author.destroy
    end
  end

  class SpecialCar < ActiveRecord::Base
    self.table_name = "cars"
    has_one :special_bulb, inverse_of: :car, dependent: :destroy, class_name: "SpecialBulb", foreign_key: "car_id"
  end

  class SpecialBulb < ActiveRecord::Base
    self.table_name = "bulbs"
    belongs_to :car, inverse_of: :special_bulb, touch: true, class_name: "SpecialCar"
  end

  def test_has_one_with_touch_option_on_nonpersisted_built_associations_doesnt_update_parent
    car = SpecialCar.create(name: "honda")
    assert_queries_count(1) do
      car.build_special_bulb
      car.build_special_bulb
    end
  end
  test "composite primary key malformed association class" do
    error = assert_raises(ActiveRecord::CompositePrimaryKeyMismatchError) do
      order = Cpk::BrokenOrder.new(id: [1, 2], book: Cpk::Book.new(title: "Some book"))
      order.save!
    end

    assert_equal(<<~MESSAGE.squish, error.message)
      Association Cpk::BrokenOrder#book primary key ["shop_id", "status"]
      doesn't match with foreign key broken_order_id. Please specify query_constraints, or primary_key and foreign_key values.
    MESSAGE
  end

  test "composite primary key malformed association owner class" do
    error = assert_raises(ActiveRecord::CompositePrimaryKeyMismatchError) do
      order = Cpk::BrokenOrderWithNonCpkBooks.new(id: [1, 2], book: Cpk::NonCpkBook.new(title: "Some book"))
      order.save!
    end

    assert_equal(<<~MESSAGE.squish, error.message)
      Association Cpk::BrokenOrderWithNonCpkBooks#book primary key [\"shop_id\", \"status\"]
      doesn't match with foreign key broken_order_with_non_cpk_books_id. Please specify query_constraints, or primary_key and foreign_key values.
    MESSAGE
  end
end

class AsyncHasOneAssociationsTest < ActiveRecord::TestCase
  include WaitForAsyncTestHelper

  self.use_transactional_tests = false

  fixtures :companies, :accounts

  unless in_memory_db?
    def test_async_load_has_one
      firm = companies(:first_firm)
      first_account = Account.find(1)

      firm.association(:account).async_load_target
      wait_for_async_query

      events = []
      callback = -> (event) do
        events << event unless event.payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        firm.account
      end

      assert_no_queries do
        assert_equal first_account, firm.account
        assert_equal first_account.credit_limit, firm.account.credit_limit
      end

      assert_equal 1, events.size
      assert_equal true, events.first.payload[:async]
    end
  end
end
