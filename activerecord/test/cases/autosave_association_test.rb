# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"
require "models/bird"
require "models/post"
require "models/comment"
require "models/category"
require "models/company"
require "models/contract"
require "models/customer"
require "models/developer"
require "models/computer"
require "models/invoice"
require "models/line_item"
require "models/mouse"
require "models/order"
require "models/parrot"
require "models/pirate"
require "models/project"
require "models/ship"
require "models/ship_part"
require "models/squeak"
require "models/tag"
require "models/tagging"
require "models/treasure"
require "models/eye"
require "models/electron"
require "models/molecule"
require "models/member"
require "models/member_detail"
require "models/organization"
require "models/guitar"
require "models/tuning_peg"
require "models/reply"
require "models/attachment"
require "models/translation"
require "models/chef"
require "models/cake_designer"
require "models/drink_designer"
require "models/cpk"

class TestAutosaveAssociationsInGeneral < ActiveRecord::TestCase
  def test_autosave_works_even_when_other_callbacks_update_the_parent_model
    reference = Class.new(ActiveRecord::Base) do
      self.table_name = "references"
      def self.name; "Reference"; end
    end

    person = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      def self.name; "Person"; end

      # It is necessary that the after_create is before the has_many _and_ that it updates the model.
      # This replicates a bug found in https://github.com/rails/rails/issues/38120
      after_create { update(first_name: "first name") }
      has_many :references, autosave: true, anonymous_class: reference
    end

    reference_instance = reference.create!
    person_instance = person.create!(first_name: "foo", references: [reference_instance])

    reference_instance.reload
    assert_equal person_instance.id, reference_instance.person_id
    assert_equal "first name", person_instance.first_name # Make sure the after_create is actually called
  end

  def test_autosave_does_not_pass_through_non_custom_validation_contexts
    person = Class.new(ActiveRecord::Base) {
      self.table_name = "people"
      validate :should_be_cool, on: :create
      def self.name; "Person"; end

      private
        def should_be_cool
          unless first_name == "cool"
            errors.add :first_name, "not cool"
          end
        end
    }
    reference = Class.new(ActiveRecord::Base) {
      self.table_name = "references"
      def self.name; "Reference"; end
      belongs_to :person, autosave: true, anonymous_class: person
    }

    u = person.create!(first_name: "cool")
    u.first_name = "nah"

    assert_predicate u, :valid?
    r = reference.new(person: u)
    assert_predicate r, :valid?
  end

  def test_autosave_collection_association_callbacks_get_called_once
    ship_with_saving_stack = Class.new(Ship) do
      def save_collection_association(reflection)
        @count ||= 0
        @count += 1 if reflection.name == :parts
        super
      end
    end

    ship = ship_with_saving_stack.new(name: "Nights Dirty Lightning")
    ship.parts.build(name: "part")
    ship.save!
    assert_equal 1, ship.instance_variable_get(:@count)
  end

  def test_autosave_has_one_association_callbacks_get_called_once
    # a bidirectional autosave is required to trigger multiple calls to
    # save_has_one_association
    assert Ship.reflect_on_association(:pirate).options[:autosave]
    assert Pirate.reflect_on_association(:ship).options[:autosave]

    pirate_with_saving_stack = Class.new(Pirate) do
      def save_has_one_association(reflection)
        @count ||= 0
        @count += 1 if reflection.name == :ship
        super
      end
    end

    pirate = pirate_with_saving_stack.new(catchphrase: "Aye")
    pirate.build_ship(name: "Nights Dirty Lightning")
    pirate.save!
    assert_equal 1, pirate.instance_variable_get(:@count)
  end

  def test_autosave_belongs_to_association_callbacks_get_called_once
    ship_with_saving_stack = Class.new(Ship) do
      def save_belongs_to_association(reflection)
        @count ||= 0
        @count += 1 if reflection.name == :pirate
        super
      end
    end

    ship = ship_with_saving_stack.new(name: "Nights Dirty Lightning")
    ship.build_pirate(catchphrase: "Aye")
    ship.save!
    assert_equal 1, ship.instance_variable_get(:@count)
  end

  def test_should_not_add_the_same_callbacks_multiple_times_for_has_one
    assert_no_difference_when_adding_callbacks_twice_for Pirate, :ship
  end

  def test_should_not_add_the_same_callbacks_multiple_times_for_belongs_to
    assert_no_difference_when_adding_callbacks_twice_for Ship, :pirate
  end

  def test_should_not_add_the_same_callbacks_multiple_times_for_has_many
    assert_no_difference_when_adding_callbacks_twice_for Pirate, :birds
  end

  def test_should_not_add_the_same_callbacks_multiple_times_for_has_and_belongs_to_many
    assert_no_difference_when_adding_callbacks_twice_for Pirate, :parrots
  end

  def test_cyclic_autosaves_do_not_add_multiple_validations
    ship = ShipWithoutNestedAttributes.new
    ship.prisoners.build

    assert_not_predicate ship, :valid?
    assert_equal 1, ship.errors[:name].length
  end

  private
    def assert_no_difference_when_adding_callbacks_twice_for(model, association_name)
      reflection = model.reflect_on_association(association_name)
      assert_not_nil reflection
      assert_no_difference "callbacks_for_model(#{model.name}).length" do
        model.send(:add_autosave_association_callbacks, reflection)
      end
    end

    def callbacks_for_model(model)
      model.instance_variables.grep(/_callbacks$/).flat_map do |ivar|
        model.instance_variable_get(ivar)
      end
    end
end

class TestDefaultAutosaveAssociationOnAHasOneAssociation < ActiveRecord::TestCase
  fixtures :companies, :accounts

  def test_should_save_parent_but_not_invalid_child
    firm = Firm.new(name: "GlobalMegaCorp")
    assert_predicate firm, :valid?

    firm.build_account_using_primary_key
    assert_not_predicate firm.build_account_using_primary_key, :valid?

    assert firm.save
    assert_not_predicate firm.account_using_primary_key, :persisted?
  end

  def test_save_fails_for_invalid_has_one
    firm = Firm.first
    assert_predicate firm, :valid?

    firm.build_account

    assert_not_predicate firm.account, :valid?
    assert_not_predicate firm, :valid?
    assert_not firm.save
    assert_equal ["is invalid"], firm.errors["account"]
  end

  def test_save_succeeds_for_invalid_has_one_with_validate_false
    firm = Firm.first
    assert_predicate firm, :valid?

    firm.build_unvalidated_account

    assert_not_predicate firm.unvalidated_account, :valid?
    assert_predicate firm, :valid?
    assert firm.save
  end

  def test_build_before_child_saved
    firm = Firm.find(1)

    account = firm.build_account("credit_limit" => 1000)
    assert_equal account, firm.account
    assert_not_predicate account, :persisted?
    assert firm.save
    assert_equal account, firm.account
    assert_predicate account, :persisted?
  end

  def test_build_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert_not_predicate account, :persisted?
    assert firm.save
    assert_equal account, firm.account
    assert_predicate account, :persisted?
  end

  def test_assignment_before_parent_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.find(1)
    assert_not_predicate firm, :persisted?
    assert_equal a, firm.account
    assert firm.save
    assert_equal a, firm.account
    firm.association(:account).reload
    assert_equal a, firm.account
  end

  def test_assignment_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.new("credit_limit" => 1000)
    assert_not_predicate firm, :persisted?
    assert_not_predicate a, :persisted?
    assert_equal a, firm.account
    assert firm.save
    assert_predicate firm, :persisted?
    assert_predicate a, :persisted?
    assert_equal a, firm.account
    firm.association(:account).reload
    assert_equal a, firm.account
  end

  def test_not_resaved_when_unchanged
    firm = Firm.all.merge!(includes: :account).first
    firm.name += "-changed"
    assert_queries_count(3) { firm.save! }

    firm = Firm.first
    firm.account = Account.first
    assert_queries_count(Firm.partial_updates? ? 0 : 1) { firm.save! }

    firm = Firm.first.dup
    firm.account = Account.first
    assert_queries_count(4) { firm.save! }

    firm = Firm.first.dup
    firm.account = Account.first.dup
    assert_queries_count(4) { firm.save! }
  end

  def test_should_not_load_the_associated_model
    firm = companies(:first_firm)
    firm.reset_unvalidated_account
    assert_no_queries { firm.save! }
  end

  def test_callbacks_firing_order_on_create
    eye = Eye.create(iris_attributes: { color: "honey" })
    assert_equal [true, false], eye.after_create_callbacks_stack
  end

  def test_callbacks_firing_order_on_update
    eye = Eye.create(iris_attributes: { color: "honey" })
    eye.update(iris_attributes: { color: "green" })
    assert_equal [true, false], eye.after_update_callbacks_stack
  end

  def test_callbacks_firing_order_on_save
    eye = Eye.create(iris_attributes: { color: "honey" })
    assert_equal [false, false], eye.after_save_callbacks_stack

    eye.update(iris_attributes: { color: "blue" })
    assert_equal [false, false, false, false], eye.after_save_callbacks_stack
  end

  def test_callbacks_on_child_when_parent_autosaves_child
    eye = Eye.create!(iris: Iris.new)
    assert_equal 1, eye.iris.before_validation_callbacks_counter
    assert_equal 1, eye.iris.before_create_callbacks_counter
    assert_equal 1, eye.iris.before_save_callbacks_counter
    assert_equal 1, eye.iris.after_validation_callbacks_counter
    assert_equal 1, eye.iris.after_create_callbacks_counter
    assert_equal 1, eye.iris.after_save_callbacks_counter
  end

  def test_callbacks_on_child_when_parent_autosaves_child_twice
    eye = Eye.create!(iris: Iris.new)
    eye.update!(iris: Iris.new)
    assert_equal 1, eye.iris.before_validation_callbacks_counter
    assert_equal 1, eye.iris.before_create_callbacks_counter
    assert_equal 1, eye.iris.before_save_callbacks_counter
    assert_equal 1, eye.iris.after_validation_callbacks_counter
    assert_equal 1, eye.iris.after_create_callbacks_counter
    assert_equal 1, eye.iris.after_save_callbacks_counter
  end

  def test_callbacks_on_child_when_parent_autosaves_polymorphic_child_with_inverse_of
    drink_designer = DrinkDesigner.create!(chef: ChefWithPolymorphicInverseOf.new)
    assert_equal 1, drink_designer.chef.before_validation_callbacks_counter
    assert_equal 1, drink_designer.chef.before_create_callbacks_counter
    assert_equal 1, drink_designer.chef.before_save_callbacks_counter
    assert_equal 1, drink_designer.chef.after_validation_callbacks_counter
    assert_equal 1, drink_designer.chef.after_create_callbacks_counter
    assert_equal 1, drink_designer.chef.after_save_callbacks_counter
  end

  def test_callbacks_on_child_when_child_autosaves_parent
    iris = Iris.create!(eye: Eye.new)
    assert_equal 1, iris.before_validation_callbacks_counter
    assert_equal 1, iris.before_create_callbacks_counter
    assert_equal 1, iris.before_save_callbacks_counter
    assert_equal 1, iris.after_validation_callbacks_counter
    assert_equal 1, iris.after_create_callbacks_counter
    assert_equal 1, iris.after_save_callbacks_counter
  end

  def test_callbacks_on_child_when_child_autosaves_parent_twice
    iris = Iris.create!(eye: Eye.new)
    iris.update!(eye: Eye.new)
    assert_equal 2, iris.before_validation_callbacks_counter
    assert_equal 1, iris.before_create_callbacks_counter
    assert_equal 2, iris.before_save_callbacks_counter
    assert_equal 2, iris.after_validation_callbacks_counter
    assert_equal 1, iris.after_create_callbacks_counter
    assert_equal 2, iris.after_save_callbacks_counter
  end

  def test_callbacks_on_child_when_polymorphic_child_with_inverse_of_autosaves_parent
    chef = ChefWithPolymorphicInverseOf.create!(employable: DrinkDesigner.new)
    assert_equal 1, chef.before_validation_callbacks_counter
    assert_equal 1, chef.before_create_callbacks_counter
    assert_equal 1, chef.before_save_callbacks_counter
    assert_equal 1, chef.after_validation_callbacks_counter
    assert_equal 1, chef.after_create_callbacks_counter
    assert_equal 1, chef.after_save_callbacks_counter
  end

  def test_foreign_key_attribute_is_not_set_unless_changed
    eye = Eye.create!(iris_with_read_only_foreign_key_attributes: { color: "honey" })
    assert_nothing_raised do
      eye.update!(override_iris_with_read_only_foreign_key_color: true)
    end
  end
end

class TestDefaultAutosaveAssociationOnABelongsToAssociation < ActiveRecord::TestCase
  fixtures :companies, :posts, :tags, :taggings

  def test_should_save_parent_but_not_invalid_child
    client = Client.new(name: "Joe (the Plumber)")
    assert_predicate client, :valid?

    client.build_firm
    assert_not_predicate client.firm, :valid?

    assert client.save
    assert_not_predicate client.firm, :persisted?
  end

  def test_save_fails_for_invalid_belongs_to
    # Oracle saves empty string as NULL therefore :message changed to one space
    assert log = AuditLog.create(developer_id: 0, message: " ")

    log.developer = Developer.new
    assert_not_predicate log.developer, :valid?
    assert_not_predicate log, :valid?
    assert_not log.save
    assert_equal ["is invalid"], log.errors["developer"]
  end

  def test_save_succeeds_for_invalid_belongs_to_with_validate_false
    # Oracle saves empty string as NULL therefore :message changed to one space
    assert log = AuditLog.create(developer_id: 0, message: " ")

    log.unvalidated_developer = Developer.new
    assert_not_predicate log.unvalidated_developer, :valid?
    assert_predicate log, :valid?
    assert log.save
  end

  def test_assignment_before_parent_saved
    client = Client.first
    apple = Firm.new("name" => "Apple")
    client.firm = apple
    assert_equal apple, client.firm
    assert_not_predicate apple, :persisted?
    assert client.save
    assert apple.save
    assert_predicate apple, :persisted?
    assert_equal apple, client.firm
    client.association(:firm).reload
    assert_equal apple, client.firm
  end

  def test_assignment_before_either_saved
    final_cut = Client.new("name" => "Final Cut")
    apple = Firm.new("name" => "Apple")
    final_cut.firm = apple
    assert_not_predicate final_cut, :persisted?
    assert_not_predicate apple, :persisted?
    assert final_cut.save
    assert_predicate final_cut, :persisted?
    assert_predicate apple, :persisted?
    assert_equal apple, final_cut.firm
    final_cut.association(:firm).reload
    assert_equal apple, final_cut.firm
  end

  def test_store_two_association_with_one_save
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.new

    customer1 = order.billing = Customer.new
    customer2 = order.shipping = Customer.new
    assert order.save
    assert_equal customer1, order.billing
    assert_equal customer2, order.shipping

    order.reload

    assert_equal customer1, order.billing
    assert_equal customer2, order.shipping

    assert_equal num_orders + 1, Order.count
    assert_equal num_customers + 2, Customer.count
  end

  def test_store_association_in_two_relations_with_one_save
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.new

    customer = order.billing = order.shipping = Customer.new
    assert order.save
    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    order.reload

    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    assert_equal num_orders + 1, Order.count
    assert_equal num_customers + 1, Customer.count
  end

  def test_store_association_in_two_relations_with_one_save_in_existing_object
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.create

    customer = order.billing = order.shipping = Customer.new
    assert order.save
    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    order.reload

    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    assert_equal num_orders + 1, Order.count
    assert_equal num_customers + 1, Customer.count
  end

  def test_store_association_in_two_relations_with_one_save_in_existing_object_with_values
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.create

    customer = order.billing = order.shipping = Customer.new
    assert order.save
    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    order.reload

    customer = order.billing = order.shipping = Customer.new

    assert order.save
    order.reload

    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    assert_equal num_orders + 1, Order.count
    assert_equal num_customers + 2, Customer.count
  end

  def test_store_association_with_a_polymorphic_relationship
    num_tagging = Tagging.count
    tags(:misc).create_tagging(taggable: posts(:thinking))
    assert_equal num_tagging + 1, Tagging.count
  end

  def test_build_and_then_save_parent_should_not_reload_target
    client = Client.first
    apple = client.build_firm(name: "Apple")
    client.save!
    assert_no_queries { assert_equal apple, client.firm }
  end

  def test_validation_does_not_validate_stale_association_target
    valid_developer   = Developer.create!(name: "Dude", salary: 50_000)
    invalid_developer = Developer.new()

    auditlog = AuditLog.new(message: "foo")
    auditlog.developer    = invalid_developer
    auditlog.developer_id = valid_developer.id

    assert_predicate auditlog, :valid?
  end

  def test_validation_does_not_validate_non_dirty_association_target
    mouse = Mouse.create!(name: "Will")
    Squeak.create!(mouse: mouse)

    mouse.name = nil
    mouse.save! validate: false

    squeak = Squeak.last

    assert_equal true, squeak.valid?
    assert_equal true, squeak.mouse.present?
    assert_equal true, squeak.valid?
  end

  test "composite primary key autosave" do
    assert_nothing_raised do
      Cpk::Order.create!(id: [1, 2], book: Cpk::Book.new(title: "Book", id: [3, 4]))
    end
  end

  def test_should_not_load_the_associated_model
    tagging = taggings(:welcome_general)
    tagging.reset_tag
    assert_no_queries { tagging.save! }
  end
end

class TestDefaultAutosaveAssociationOnAHasManyAssociationWithAcceptsNestedAttributes < ActiveRecord::TestCase
  def test_invalid_adding_with_nested_attributes
    molecule = Molecule.new
    valid_electron = Electron.new(name: "electron")
    invalid_electron = Electron.new

    molecule.electrons = [valid_electron, invalid_electron]
    molecule.save

    assert_not_predicate invalid_electron, :valid?
    assert_predicate valid_electron, :valid?
    assert_not molecule.persisted?, "Molecule should not be persisted when its electrons are invalid"
  end

  def test_errors_should_be_indexed_when_passed_as_array
    guitar = Guitar.new
    tuning_peg_valid = TuningPeg.new
    tuning_peg_valid.pitch = 440.0
    tuning_peg_invalid = TuningPeg.new

    guitar.tuning_pegs = [tuning_peg_valid, tuning_peg_invalid]

    assert_not_predicate tuning_peg_invalid, :valid?
    assert_predicate tuning_peg_valid, :valid?
    assert_not_predicate guitar, :valid?
    assert_equal ["is not a number"], guitar.errors["tuning_pegs[1].pitch"]
    assert_not_equal ["is not a number"], guitar.errors["tuning_pegs.pitch"]
  end

  def test_errors_should_be_indexed_when_global_flag_is_set
    old_attribute_config = ActiveRecord.index_nested_attribute_errors
    ActiveRecord.index_nested_attribute_errors = true

    molecule = Molecule.new
    valid_electron = Electron.new(name: "electron")
    invalid_electron = Electron.new

    molecule.electrons = [valid_electron, invalid_electron]

    assert_not_predicate invalid_electron, :valid?
    assert_predicate valid_electron, :valid?
    assert_not_predicate molecule, :valid?
    assert_equal ["can't be blank"], molecule.errors["electrons[1].name"]
    assert_not_equal ["can't be blank"], molecule.errors["electrons.name"]
  ensure
    ActiveRecord.index_nested_attribute_errors = old_attribute_config
  end

  def test_errors_details_should_be_set
    molecule = Molecule.new
    valid_electron = Electron.new(name: "electron")
    invalid_electron = Electron.new

    molecule.electrons = [valid_electron, invalid_electron]

    assert_not_predicate invalid_electron, :valid?
    assert_predicate valid_electron, :valid?
    assert_not_predicate molecule, :valid?
    assert_equal [{ error: :blank }], molecule.errors.details[:"electrons.name"]
  end

  def test_errors_details_should_be_indexed_when_passed_as_array
    guitar = Guitar.new
    tuning_peg_valid = TuningPeg.new
    tuning_peg_valid.pitch = 440.0
    tuning_peg_invalid = TuningPeg.new

    guitar.tuning_pegs = [tuning_peg_valid, tuning_peg_invalid]

    assert_not_predicate tuning_peg_invalid, :valid?
    assert_predicate tuning_peg_valid, :valid?
    assert_not_predicate guitar, :valid?
    assert_equal [{ error: :not_a_number, value: nil }], guitar.errors.details[:"tuning_pegs[1].pitch"]
    assert_equal [], guitar.errors.details[:"tuning_pegs.pitch"]
  end

  def test_errors_details_with_error_on_base_should_be_indexed_when_passed_as_array
    reference = Class.new(ActiveRecord::Base) do
      self.table_name = "references"
      def self.name; "Reference"; end

      validate :should_be_favorite

      private
        def should_be_favorite
          errors.add(:base, "should be favorite") unless favorite?
        end
    end

    person = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      has_many :references, autosave: true, index_errors: true, anonymous_class: reference
      def self.name; "Person"; end
    end

    p = person.new
    reference_valid = reference.new(favorite: true)
    reference_invalid = reference.new(favorite: false)
    p.references = [reference_valid, reference_invalid]

    assert_predicate reference_valid, :valid?
    assert_not_predicate reference_invalid, :valid?
    assert_not_predicate p, :valid?
    assert_equal [{ error: "should be favorite" }], p.errors.details[:"references[1].base"]
    assert_equal "should be favorite", p.errors[:"references[1].base"].first
    assert_equal ["References[1] should be favorite"], p.errors.full_messages
  end

  def test_indexed_errors_should_be_properly_translated
    old_i18n_customize_full_message = ActiveModel::Error.i18n_customize_full_message
    ActiveModel::Error.i18n_customize_full_message = true
    I18n.backend.store_translations(
      :en,
      activerecord: {
        errors: {
          models: {
            "person/references": {
              format: "%{message}"
            }
          }
        }
      }
    )
    reference = Class.new(ActiveRecord::Base) do
      self.table_name = "references"
      def self.name; "Reference"; end

      validate :should_be_favorite
      validates_presence_of :job_id

      private
        def should_be_favorite
          errors.add(:base, "should be favorite") unless favorite?
        end
    end

    person = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      has_many :references, autosave: true, index_errors: true, anonymous_class: reference
      def self.name; "Person"; end
    end

    p = person.new
    reference_valid = reference.new(favorite: true, job_id: 1)
    reference_invalid = reference.new(favorite: false)
    p.references = [reference_valid, reference_invalid]

    assert_predicate reference_valid, :valid?
    assert_not_predicate reference_invalid, :valid?
    assert_not_predicate p, :valid?
    assert_equal ["should be favorite", "can't be blank"], p.errors.full_messages
  ensure
    ActiveModel::Error.i18n_customize_full_message = old_i18n_customize_full_message
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_indexed_errors_on_base_attribute_should_be_properly_translated
    I18n.backend.store_translations(
      :en,
      activerecord: {
        attributes: {
          person: {
            reference: "Super reference",
          },
          reference: {
            base: ""
          }
        }
      }
    )
    reference = Class.new(ActiveRecord::Base) do
      self.table_name = "references"
      def self.name; "Reference"; end

      validate :should_be_favorite
      validates_presence_of :job_id

      private
        def should_be_favorite
          errors.add(:base, "should be favorite") unless favorite?
        end
    end

    person = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      def self.name; "Person"; end

      has_one :reference, autosave: true, anonymous_class: reference
      validates :reference, presence: true
    end

    p = person.new
    assert_not_predicate p, :valid?
    assert_equal ["Super reference can't be blank"], p.errors.full_messages

    reference_invalid = reference.new(favorite: false)
    p.reference = reference_invalid

    assert_not_predicate reference_invalid, :valid?
    assert_not_predicate p, :valid?
    assert_equal [" should be favorite", "Reference job can't be blank"], p.errors.full_messages
  ensure
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_errors_details_should_be_indexed_when_global_flag_is_set
    old_attribute_config = ActiveRecord.index_nested_attribute_errors
    ActiveRecord.index_nested_attribute_errors = true

    molecule = Molecule.new
    valid_electron = Electron.new(name: "electron")
    invalid_electron = Electron.new

    molecule.electrons = [valid_electron, invalid_electron]

    assert_not_predicate invalid_electron, :valid?
    assert_predicate valid_electron, :valid?
    assert_not_predicate molecule, :valid?
    assert_equal [{ error: :blank }], molecule.errors.details[:"electrons[1].name"]
    assert_equal [], molecule.errors.details[:"electrons.name"]
  ensure
    ActiveRecord.index_nested_attribute_errors = old_attribute_config
  end

  def test_valid_adding_with_nested_attributes
    molecule = Molecule.new
    valid_electron = Electron.new(name: "electron")

    molecule.electrons = [valid_electron]
    molecule.save

    assert_predicate valid_electron, :valid?
    assert_predicate molecule, :persisted?
    assert_equal 1, molecule.electrons.count
  end
end

class TestDefaultAutosaveAssociationOnAHasManyAssociation < ActiveRecord::TestCase
  fixtures :companies, :developers, :cpk_order_agreements, :cpk_orders, :cpk_books

  def test_invalid_adding
    firm = Firm.find(1)
    assert_not (firm.clients_of_firm << c = Client.new)
    assert_not_predicate c, :persisted?
    assert_not_predicate firm, :valid?
    assert_not firm.save
    assert_not_predicate c, :persisted?
  end

  def test_invalid_adding_before_save
    new_firm = Firm.new("name" => "A New Firm, Inc")
    new_firm.clients_of_firm.concat([c = Client.new, Client.new("name" => "Apple")])
    assert_not_predicate c, :persisted?
    assert_not_predicate c, :valid?
    assert_not_predicate new_firm, :valid?
    assert_not new_firm.save
    assert_not_predicate c, :persisted?
    assert_not_predicate new_firm, :persisted?
  end

  def test_adding_unsavable_association
    new_firm = Firm.new("name" => "A New Firm, Inc")
    client = new_firm.clients.new("name" => "Apple")
    client.throw_on_save = true

    assert_predicate client, :valid?
    assert_predicate new_firm, :valid?
    assert_not new_firm.save
    assert_not_predicate new_firm, :persisted?
    assert_not_predicate client, :persisted?
  end

  def test_invalid_adding_with_validate_false
    firm = Firm.first
    client = Client.new
    firm.unvalidated_clients_of_firm << client

    assert_predicate firm, :valid?
    assert_not_predicate client, :valid?
    assert firm.save
    assert_not_predicate client, :persisted?
  end

  def test_valid_adding_with_validate_false
    no_of_clients = Client.count

    firm = Firm.first
    client = Client.new("name" => "Apple")

    assert_predicate firm, :valid?
    assert_predicate client, :valid?
    assert_not_predicate client, :persisted?

    firm.unvalidated_clients_of_firm << client

    assert firm.save
    assert_predicate client, :persisted?
    assert_equal no_of_clients + 1, Client.count
  end

  def test_parent_should_save_children_record_with_foreign_key_validation_set_in_before_save_callback
    company = NewlyContractedCompany.new(name: "test")

    assert company.save
    assert_not_empty company.reload.new_contracts
  end

  def test_parent_should_not_get_saved_with_duplicate_children_records
    assert_no_difference "Reply.count" do
      assert_no_difference "SillyUniqueReply.count" do
        reply = Reply.new
        reply.silly_unique_replies.build([
          { content: "Best content" },
          { content: "Best content" }
        ])

        assert_not reply.save
        assert_equal ["is invalid"], reply.errors[:silly_unique_replies]
        assert_empty reply.silly_unique_replies.first.errors

        assert_equal(
          ["has already been taken"],
          reply.silly_unique_replies.last.errors[:content]
        )
      end
    end
  end

  def test_invalid_build
    new_client = companies(:first_firm).clients_of_firm.build
    assert_not_predicate new_client, :persisted?
    assert_not_predicate new_client, :valid?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert_not companies(:first_firm).save
    assert_not_predicate new_client, :persisted?
    assert_equal 2, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_adding_before_save
    no_of_firms = Firm.count
    no_of_clients = Client.count

    new_firm = Firm.new("name" => "A New Firm, Inc")
    c = Client.new("name" => "Apple")

    new_firm.clients_of_firm.push Client.new("name" => "Natural Company")
    assert_equal 1, new_firm.clients_of_firm.size
    new_firm.clients_of_firm << c
    assert_equal 2, new_firm.clients_of_firm.size

    assert_equal no_of_firms, Firm.count      # Firm was not saved to database.
    assert_equal no_of_clients, Client.count  # Clients were not saved to database.
    assert new_firm.save
    assert_predicate new_firm, :persisted?
    assert_predicate c, :persisted?
    assert_equal new_firm, c.firm
    assert_equal no_of_firms + 1, Firm.count      # Firm was saved to database.
    assert_equal no_of_clients + 2, Client.count  # Clients were saved to database.

    assert_equal 2, new_firm.clients_of_firm.size
    assert_equal 2, new_firm.clients_of_firm.reload.size
  end

  def test_assign_ids
    firm = Firm.new("name" => "Apple")
    firm.client_ids = [companies(:first_client).id, companies(:second_client).id]
    firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert_includes firm.clients, companies(:second_client)
  end

  def test_assign_ids_with_belongs_to_cpk_model
    order_agreements = [cpk_order_agreements(:order_agreement_one).id, cpk_order_agreements(:order_agreement_two).id]
    order = cpk_orders(:cpk_groceries_order_1)

    assert_empty order.order_agreements

    order.order_agreement_ids = order_agreements
    order.save
    order.reload

    assert_equal order_agreements, order.order_agreement_ids
    assert_equal 2, order.order_agreements.length
    assert_includes order.order_agreements, cpk_order_agreements(:order_agreement_two)
  end

  def test_assign_ids_with_cpk_for_two_models
    book_ids = [cpk_books(:cpk_great_author_first_book).id, cpk_books(:cpk_great_author_second_book).id]
    order = cpk_orders(:cpk_groceries_order_1)

    assert_empty order.books

    order.book_ids = book_ids
    order.save
    order.reload

    assert_equal book_ids, order.book_ids
    assert_equal 2, order.books.length
    assert_includes order.books, cpk_books(:cpk_great_author_first_book)
    assert_includes order.books, cpk_books(:cpk_great_author_second_book)
  end

  def test_has_one_cpk_has_one_autosave_with_id
    book = Cpk::Book.create!(id: [1, 3], shop_id: 2)
    order = Cpk::OrderWithPrimaryKeyAssociatedBook.create!(book: book, shop_id: 2)

    assert_equal(book.order.id, order.id)
  end

  def test_assign_ids_for_through_a_belongs_to
    firm = Firm.new("name" => "Apple")
    firm.developer_ids = [developers(:david).id, developers(:jamis).id]
    firm.save
    firm.reload
    assert_equal 2, firm.developers.length
    assert_includes firm.developers, developers(:david)
  end

  def test_build_before_save
    company = companies(:first_firm)

    new_client = assert_queries_count(0) { company.clients_of_firm.build("name" => "Another Client") }
    assert_not_predicate company.clients_of_firm, :loaded?

    company.name += "-changed"
    assert_queries_count(4) { assert company.save }
    assert_predicate new_client, :persisted?
    assert_equal 3, company.clients_of_firm.reload.size
  end

  def test_build_many_before_save
    company = companies(:first_firm)

    assert_queries_count(0) { company.clients_of_firm.build([{ "name" => "Another Client" }, { "name" => "Another Client II" }]) }

    company.name += "-changed"
    assert_queries_count(5) { assert company.save }
    assert_equal 4, company.clients_of_firm.reload.size
  end

  def test_build_via_block_before_save
    company = companies(:first_firm)

    new_client = assert_queries_count(0) { company.clients_of_firm.build { |client| client.name = "Another Client" } }
    assert_not_predicate company.clients_of_firm, :loaded?

    company.name += "-changed"
    assert_queries_count(4) { assert company.save }
    assert_predicate new_client, :persisted?
    assert_equal 3, company.clients_of_firm.reload.size
  end

  def test_build_many_via_block_before_save
    company = companies(:first_firm)

    assert_queries_count(0) do
      company.clients_of_firm.build([{ "name" => "Another Client" }, { "name" => "Another Client II" }]) do |client|
        client.name = "changed"
      end
    end

    company.name += "-changed"
    assert_queries_count(5) { assert company.save }
    assert_equal 4, company.clients_of_firm.reload.size
  end

  def test_replace_on_new_object
    firm = Firm.new("name" => "New Firm")
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    assert firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert_includes firm.clients, Client.find_by_name("New Client")
  end

  def test_replace_on_duplicated_object
    firm = Firm.create!("name" => "New Firm").dup
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    assert firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert_includes firm.clients, Client.find_by_name("New Client")
  end

  def test_should_not_load_the_associated_model
    firm = companies(:first_firm)
    firm.clients.reset
    assert_no_queries { firm.save! }
  end
end

class TestDefaultAutosaveAssociationOnNewRecord < ActiveRecord::TestCase
  def test_autosave_new_record_on_belongs_to_can_be_disabled_per_relationship
    new_account = Account.new("credit_limit" => 1000)
    new_firm = Firm.new("name" => "some firm")

    assert_not_predicate new_firm, :persisted?
    new_account.firm = new_firm
    new_account.save!

    assert_predicate new_firm, :persisted?

    new_account = Account.new("credit_limit" => 1000)
    new_autosaved_firm = Firm.new("name" => "some firm")

    assert_not_predicate new_autosaved_firm, :persisted?
    new_account.unautosaved_firm = new_autosaved_firm
    new_account.save!

    assert_not_predicate new_autosaved_firm, :persisted?
  end

  def test_autosave_new_record_on_has_one_can_be_disabled_per_relationship
    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    assert_not_predicate account, :persisted?
    firm.account = account
    firm.save!

    assert_predicate account, :persisted?

    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    firm.unautosaved_account = account

    assert_not_predicate account, :persisted?
    firm.unautosaved_account = account
    firm.save!

    assert_not_predicate account, :persisted?
  end

  def test_autosave_new_record_on_has_many_can_be_disabled_per_relationship
    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    assert_not_predicate account, :persisted?
    firm.accounts << account

    firm.save!
    assert_predicate account, :persisted?

    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    assert_not_predicate account, :persisted?
    firm.unautosaved_accounts << account

    firm.save!
    assert_not_predicate account, :persisted?
  end

  def test_autosave_new_record_with_after_create_callback
    post = PostWithAfterCreateCallback.new(title: "Captain Murphy", body: "is back")
    post.comments.build(body: "foo")
    post.save!

    assert_not_nil post.author_id
  end

  def test_autosave_new_record_with_after_create_callback_and_habtm_association
    post = PostWithAfterCreateCallback.new(title: "Captain Murphy", body: "is back")
    post.comments.build(body: "foo")
    post.categories.build(name: "bar")
    post.save!

    assert_equal 1, post.categories.reload.length
  end
end

class TestDestroyAsPartOfAutosaveAssociation < ActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(name: "Nights Dirty Lightning")
  end

  teardown do
    # We are running without transactional tests and need to cleanup.
    Bird.delete_all
    Parrot.delete_all
    @ship.delete
    @pirate.delete
    Cpk::Book.delete_all
    Cpk::Order.delete_all
  end

  # reload
  def test_a_marked_for_destruction_record_should_not_be_be_marked_after_reload
    @pirate.mark_for_destruction
    @pirate.ship.mark_for_destruction

    assert_not_predicate @pirate.reload, :marked_for_destruction?
    assert_not_predicate @pirate.ship.reload, :marked_for_destruction?
  end

  # has_one
  def test_should_destroy_a_child_association_as_part_of_the_save_transaction_if_it_was_marked_for_destruction
    assert_not_predicate @pirate.ship, :marked_for_destruction?

    @pirate.ship.mark_for_destruction
    id = @pirate.ship.id

    assert_predicate @pirate.ship, :marked_for_destruction?
    assert Ship.find_by_id(id)

    @pirate.save
    assert_nil @pirate.reload.ship
    assert_nil Ship.find_by_id(id)
  end

  def test_should_skip_validation_on_a_child_association_if_marked_for_destruction
    @pirate.ship.name = ""
    assert_not_predicate @pirate, :valid?

    @pirate.ship.mark_for_destruction
    assert_not_called(@pirate.ship, :valid?) do
      assert_difference("Ship.count", -1) { @pirate.save! }
    end
  end

  def test_a_child_marked_for_destruction_should_not_be_destroyed_twice
    @pirate.ship.mark_for_destruction
    assert @pirate.save
    class << @pirate.ship
      def destroy; raise "Should not be called" end
    end
    assert @pirate.save
  end

  def test_should_rollback_destructions_if_an_exception_occurred_while_saving_a_child
    # Stub the save method of the @pirate.ship instance to destroy and then raise an exception
    class << @pirate.ship
      def save(**)
        super
        destroy
        raise "Oh noes!"
      end
    end

    @ship.pirate.catchphrase = "Changed Catchphrase"
    @ship.name_will_change!

    assert_raise(RuntimeError) { assert_not @pirate.save }
    assert_not_nil @pirate.reload.ship
  end

  def test_should_save_changed_has_one_changed_object_if_child_is_saved
    @pirate.ship.name = "NewName"
    assert @pirate.save
    assert_equal "NewName", @pirate.ship.reload.name
  end

  def test_should_not_save_changed_has_one_unchanged_object_if_child_is_saved
    assert_not_called(@pirate.ship, :save) do
      assert @pirate.save
    end
  end

  # belongs_to
  def test_should_destroy_a_parent_association_as_part_of_the_save_transaction_if_it_was_marked_for_destruction
    assert_not_predicate @ship.pirate, :marked_for_destruction?

    @ship.pirate.mark_for_destruction
    id = @ship.pirate.id

    assert_predicate @ship.pirate, :marked_for_destruction?
    assert Pirate.find_by_id(id)

    @ship.save
    assert_nil @ship.reload.pirate
    assert_nil Pirate.find_by_id(id)
  end

  # belongs_to for CPK
  def test_autosave_cpk_association_should_destroy_parent_association_when_marked_for_destruction
    book = Cpk::Book.new(title: "Book", id: [1, 2])
    Cpk::Order.create!(id: [3, 4], book: book)

    book.order.mark_for_destruction

    assert book.save
    assert_nil book.reload.order
    assert_nil Cpk::Order.find_by(id: 4, shop_id: 3)
  end

  def test_should_skip_validation_on_a_parent_association_if_marked_for_destruction
    @ship.pirate.catchphrase = ""
    assert_not_predicate @ship, :valid?

    @ship.pirate.mark_for_destruction
    assert_not_called(@ship.pirate, :valid?) do
      assert_difference("Pirate.count", -1) { @ship.save! }
    end
  end

  def test_a_parent_marked_for_destruction_should_not_be_destroyed_twice
    @ship.pirate.mark_for_destruction
    assert @ship.save
    class << @ship.pirate
      def destroy; raise "Should not be called" end
    end
    assert @ship.save
  end

  def test_should_rollback_destructions_if_an_exception_occurred_while_saving_a_parent
    # Stub the save method of the @ship.pirate instance to destroy and then raise an exception
    class << @ship.pirate
      def save(**)
        super
        destroy
        raise "Oh noes!"
      end
    end

    @ship.pirate.catchphrase = "Changed Catchphrase"

    assert_raise(RuntimeError) { assert_not @ship.save }
    assert_not_nil @ship.reload.pirate
  end

  def test_should_save_changed_child_objects_if_parent_is_saved
    @pirate = @ship.create_pirate(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @parrot = @pirate.parrots.create!(name: "Posideons Killer")
    @parrot.name = "NewName"
    @ship.save

    assert_equal "NewName", @parrot.reload.name
  end

  def test_should_destroy_has_many_as_part_of_the_save_transaction_if_they_were_marked_for_destruction
    2.times { |i| @pirate.birds.create!(name: "birds_#{i}") }

    assert_not @pirate.birds.any?(&:marked_for_destruction?)

    @pirate.birds.each(&:mark_for_destruction)
    klass = @pirate.birds.first.class
    ids = @pirate.birds.map(&:id)

    assert @pirate.birds.all?(&:marked_for_destruction?)
    ids.each { |id| assert klass.find_by_id(id) }

    @pirate.save
    assert_empty @pirate.reload.birds
    ids.each { |id| assert_nil klass.find_by_id(id) }
  end

  def test_should_not_resave_destroyed_association
    @pirate.birds.create!(name: :parrot)
    @pirate.birds.first.destroy
    @pirate.save!
    assert_empty @pirate.reload.birds
  end

  def test_should_skip_validation_on_has_many_if_marked_for_destruction
    2.times { |i| @pirate.birds.create!(name: "birds_#{i}") }

    @pirate.birds.each { |bird| bird.name = "" }
    assert_not_predicate @pirate, :valid?

    @pirate.birds.each(&:mark_for_destruction)

    assert_not_called(@pirate.birds.first, :valid?) do
      assert_not_called(@pirate.birds.last, :valid?) do
        assert_difference("Bird.count", -2) { @pirate.save! }
      end
    end
  end

  def test_should_skip_validation_on_has_many_if_destroyed
    @pirate.birds.create!(name: "birds_1")

    @pirate.birds.each { |bird| bird.name = "" }
    assert_not_predicate @pirate, :valid?

    @pirate.birds.each(&:destroy)
    assert_predicate @pirate, :valid?
  end

  def test_a_child_marked_for_destruction_should_not_be_destroyed_twice_while_saving_has_many
    @pirate.birds.create!(name: "birds_1")

    @pirate.birds.each(&:mark_for_destruction)
    assert @pirate.save

    @pirate.birds.each do |bird|
      assert_not_called(bird, :destroy) do
        assert @pirate.save
      end
    end
  end

  def test_should_rollback_destructions_if_an_exception_occurred_while_saving_has_many
    2.times { |i| @pirate.birds.create!(name: "birds_#{i}") }
    before = @pirate.birds.map { |c| c.mark_for_destruction ; c }

    # Stub the destroy method of the second child to raise an exception
    class << before.last
      def destroy(*args)
        super
        raise "Oh noes!"
      end
    end

    assert_raise(RuntimeError) { assert_not @pirate.save }
    assert_equal before, @pirate.reload.birds
  end

  def test_when_new_record_a_child_marked_for_destruction_should_not_affect_other_records_from_saving
    @pirate = @ship.build_pirate(catchphrase: "Arr' now I shall keep me eye on you matey!") # new record

    3.times { |i| @pirate.birds.build(name: "birds_#{i}") }
    @pirate.birds[1].mark_for_destruction
    @pirate.save!

    assert_equal 2, @pirate.birds.reload.length
  end

  def test_should_save_new_record_that_has_same_value_as_existing_record_marked_for_destruction_on_field_that_has_unique_index
    Bird.lease_connection.add_index :birds, :name, unique: true

    3.times { |i| @pirate.birds.create(name: "unique_birds_#{i}") }

    @pirate.birds[0].mark_for_destruction
    @pirate.birds.build(name: @pirate.birds[0].name)
    @pirate.save!

    assert_equal 3, @pirate.birds.reload.length
  ensure
    Bird.lease_connection.remove_index :birds, column: :name
  end

  # Add and remove callbacks tests for association collections.
  %w{ method proc }.each do |callback_type|
    define_method("test_should_run_add_callback_#{callback_type}s_for_has_many") do
      association_name_with_callbacks = "birds_with_#{callback_type}_callbacks"

      pirate = Pirate.new(catchphrase: "Arr")
      pirate.public_send(association_name_with_callbacks).build(name: "Crowe the One-Eyed")

      expected = [
        "before_adding_#{callback_type}_bird_<new>",
        "after_adding_#{callback_type}_bird_<new>"
      ]

      assert_equal expected, pirate.ship_log
    end

    define_method("test_should_run_remove_callback_#{callback_type}s_for_has_many") do
      association_name_with_callbacks = "birds_with_#{callback_type}_callbacks"

      @pirate.public_send(association_name_with_callbacks).create!(name: "Crowe the One-Eyed")
      @pirate.public_send(association_name_with_callbacks).each(&:mark_for_destruction)
      child_id = @pirate.public_send(association_name_with_callbacks).first.id

      @pirate.ship_log.clear
      @pirate.save

      expected = [
        "before_removing_#{callback_type}_bird_#{child_id}",
        "after_removing_#{callback_type}_bird_#{child_id}"
      ]

      assert_equal expected, @pirate.ship_log
    end
  end

  def test_should_destroy_habtm_as_part_of_the_save_transaction_if_they_were_marked_for_destruction
    2.times { |i| @pirate.parrots.create!(name: "parrots_#{i}") }

    assert_not @pirate.parrots.any?(&:marked_for_destruction?)
    @pirate.parrots.each(&:mark_for_destruction)

    assert_no_difference "Parrot.count" do
      @pirate.save
    end

    assert_empty @pirate.reload.parrots

    join_records = Pirate.lease_connection.select_all("SELECT * FROM parrots_pirates WHERE pirate_id = #{@pirate.id}")
    assert_empty join_records
  end

  def test_should_skip_validation_on_habtm_if_marked_for_destruction
    2.times { |i| @pirate.parrots.create!(name: "parrots_#{i}") }

    @pirate.parrots.each { |parrot| parrot.name = "" }
    assert_not_predicate @pirate, :valid?

    @pirate.parrots.each { |parrot| parrot.mark_for_destruction }

    assert_not_called(@pirate.parrots.first, :valid?) do
      assert_not_called(@pirate.parrots.last, :valid?) do
        @pirate.save!
      end
    end

    assert_empty @pirate.reload.parrots
  end

  def test_should_skip_validation_on_habtm_if_destroyed
    @pirate.parrots.create!(name: "parrots_1")

    @pirate.parrots.each { |parrot| parrot.name = "" }
    assert_not_predicate @pirate, :valid?

    @pirate.parrots.each(&:destroy)
    assert_predicate @pirate, :valid?
  end

  def test_a_child_marked_for_destruction_should_not_be_destroyed_twice_while_saving_habtm
    @pirate.parrots.create!(name: "parrots_1")

    @pirate.parrots.each(&:mark_for_destruction)
    assert @pirate.save

    Pirate.transaction do
      assert_no_queries do
        assert @pirate.save
      end
    end
  end

  def test_should_rollback_destructions_if_an_exception_occurred_while_saving_habtm
    2.times { |i| @pirate.parrots.create!(name: "parrots_#{i}") }
    before = @pirate.parrots.map { |c| c.mark_for_destruction ; c }

    class << @pirate.association(:parrots)
      def destroy(*args)
        super
        raise "Oh noes!"
      end
    end

    assert_raise(RuntimeError) { assert_not @pirate.save }
    assert_equal before, @pirate.reload.parrots
  end

  # Add and remove callbacks tests for association collections.
  %w{ method proc }.each do |callback_type|
    define_method("test_should_run_add_callback_#{callback_type}s_for_habtm") do
      association_name_with_callbacks = "parrots_with_#{callback_type}_callbacks"

      pirate = Pirate.new(catchphrase: "Arr")
      pirate.public_send(association_name_with_callbacks).build(name: "Crowe the One-Eyed")

      expected = [
        "before_adding_#{callback_type}_parrot_<new>",
        "after_adding_#{callback_type}_parrot_<new>"
      ]

      assert_equal expected, pirate.ship_log
    end

    define_method("test_should_run_remove_callback_#{callback_type}s_for_habtm") do
      association_name_with_callbacks = "parrots_with_#{callback_type}_callbacks"

      @pirate.public_send(association_name_with_callbacks).create!(name: "Crowe the One-Eyed")
      @pirate.public_send(association_name_with_callbacks).each(&:mark_for_destruction)
      child_id = @pirate.public_send(association_name_with_callbacks).first.id

      @pirate.ship_log.clear
      @pirate.save

      expected = [
        "before_removing_#{callback_type}_parrot_#{child_id}",
        "after_removing_#{callback_type}_parrot_#{child_id}"
      ]

      assert_equal expected, @pirate.ship_log
    end
  end
end

class TestAutosaveAssociationOnAHasOneAssociation < ActiveRecord::TestCase
  fixtures :chefs, :cake_designers, :drink_designers

  def setup
    super
    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(name: "Nights Dirty Lightning")
  end

  def test_should_still_work_without_an_associated_model
    @ship.destroy
    @pirate.reload.catchphrase = "Arr"
    @pirate.save
    assert_equal "Arr", @pirate.reload.catchphrase
  end

  def test_should_automatically_save_the_associated_model
    @pirate.ship.name = "The Vile Serpent"
    @pirate.save
    assert_equal "The Vile Serpent", @pirate.reload.ship.name
  end

  def test_changed_for_autosave_should_handle_cycles
    @ship.pirate = @pirate
    assert_no_queries { @ship.save! }

    @parrot = @pirate.parrots.create(name: "some_name")
    @parrot.name = "changed_name"
    assert_queries_count(3) { @ship.save! }
    assert_no_queries { @ship.save! }
  end

  def test_should_automatically_save_bang_the_associated_model
    @pirate.ship.name = "The Vile Serpent"
    @pirate.save!
    assert_equal "The Vile Serpent", @pirate.reload.ship.name
  end

  def test_should_automatically_save_bang_the_associated_model_if_it_sets_the_inverse_record
    pirate = Pirate.new(catchphrase: "Savvy?")
    ship = Ship.new(name: "Black Pearl")
    ship.pirate = pirate
    pirate.save!
    assert_equal "Black Pearl", pirate.reload.ship.name
  end

  def test_should_automatically_validate_the_associated_model
    @pirate.ship.name = ""
    assert_predicate @pirate, :invalid?
    assert_predicate @pirate.errors[:"ship.name"], :any?
  end

  def test_should_merge_errors_on_the_associated_models_onto_the_parent_even_if_it_is_not_valid
    @pirate.ship.name   = nil
    @pirate.catchphrase = nil
    assert_predicate @pirate, :invalid?
    assert_predicate @pirate.errors[:"ship.name"], :any?
    assert_predicate @pirate.errors[:catchphrase], :any?
  end

  def test_should_not_ignore_different_error_messages_on_the_same_attribute
    old_validators = Ship._validators.deep_dup
    old_callbacks = Ship._validate_callbacks.deep_dup
    Ship.validates_format_of :name, with: /\w/
    @pirate.ship.name   = ""
    @pirate.catchphrase = nil
    assert_predicate @pirate, :invalid?
    assert_equal ["can't be blank", "is invalid"], @pirate.errors[:"ship.name"]
  ensure
    Ship._validators = old_validators if old_validators
    Ship._validate_callbacks = old_callbacks if old_callbacks
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_model
    @pirate.catchphrase = ""
    @pirate.ship.name = ""
    @pirate.save(validate: false)
    assert_equal ["", ""], [@pirate.reload.catchphrase, @pirate.ship.name]
  end

  def test_should_allow_to_bypass_validations_on_associated_models_at_any_depth
    2.times { |i| @pirate.ship.parts.create!(name: "part #{i}") }

    @pirate.catchphrase = ""
    @pirate.ship.name = ""
    @pirate.ship.parts.each { |part| part.name = "" }
    @pirate.save(validate: false)

    values = [@pirate.reload.catchphrase, @pirate.ship.name, *@pirate.ship.parts.map(&:name)]
    assert_equal ["", "", "", ""], values
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @pirate.ship.name = ""
    assert_raise(ActiveRecord::RecordInvalid) do
      @pirate.save!
    end
  end

  def test_should_not_save_and_return_false_if_a_callback_cancelled_saving
    pirate = Pirate.new(catchphrase: "Arr")
    ship = pirate.build_ship(name: "The Vile Serpent")
    ship.cancel_save_from_callback = true

    assert_no_difference "Pirate.count" do
      assert_no_difference "Ship.count" do
        assert_not pirate.save
      end
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@pirate.catchphrase, @pirate.ship.name]

    @pirate.catchphrase = "Arr"
    @pirate.ship.name = "The Vile Serpent"

    # Stub the save method of the @pirate.ship instance to raise an exception
    class << @pirate.ship
      def save(**)
        super
        raise "Oh noes!"
      end
    end

    assert_raise(RuntimeError) { assert_not @pirate.save }
    assert_equal before, [@pirate.reload.catchphrase, @pirate.ship.name]
  end

  def test_should_not_load_the_associated_model
    assert_queries_count(3) { @pirate.catchphrase = "Arr"; @pirate.save! }
  end

  def test_mark_for_destruction_is_ignored_without_autosave_true
    ship = ShipWithoutNestedAttributes.new(name: "The Black Flag")
    ship.parts.build.mark_for_destruction

    assert_not_predicate ship, :valid?
  end

  def test_recognises_inverse_polymorphic_association_changes_with_same_foreign_key
    chef_a = chefs(:gordon_ramsay)
    chef_b = chefs(:marco_pierre_white)

    cake_designer_a = cake_designers(:flora) # id: 1
    cake_designer_a.update!(chef: chef_a)
    cake_designer_b = cake_designers(:frosty) # id: 3
    cake_designer_b.update!(chef: chef_b)

    drink_designer_a = drink_designers(:turner) # id: 1
    drink_designer_b = drink_designers(:sparrow) # id: 2

    swap_chefs(cake_designer_b, drink_designer_b)
    assert_predicate cake_designer_b.reload.chef, :present?
    assert_not_predicate drink_designer_b.reload.chef, :present?

    swap_chefs(cake_designer_a, drink_designer_a)
    assert_predicate cake_designer_a.reload.chef, :present?
    assert_not_predicate drink_designer_a.reload.chef, :present?
  end

  private
    def swap_chefs(cake_designer, drink_designer)
      drink_designer.chef = cake_designer.chef
      drink_designer.save!
      cake_designer.save!
    end
end

class TestAutosaveAssociationOnAHasOneThroughAssociation < ActiveRecord::TestCase
  def create_member_with_organization
    organization = Organization.create
    member = Member.create
    MemberDetail.create(organization: organization, member: member)

    member
  end

  def test_should_not_has_one_through_model
    member = create_member_with_organization

    class << member.organization
      def save(**)
        super
        raise "Oh noes!"
      end
    end
    assert_nothing_raised { member.save }
  end

  def create_author_with_post_with_comment
    Author.create! name: "David" # make comment_id not match author_id
    author = Author.create! name: "Sergiy"
    post = Post.create! author: author, title: "foo", body: "bar"
    Comment.create! post: post, body: "cool comment"

    author
  end

  def test_should_not_reversed_has_one_through_model
    author = create_author_with_post_with_comment

    class << author.comment_on_first_post
      def save(**)
        super
        raise "Oh noes!"
      end
    end
    assert_nothing_raised { author.save }
  end
end

class TestAutosaveAssociationOnABelongsToAssociation < ActiveRecord::TestCase
  def setup
    super
    @ship = Ship.create(name: "Nights Dirty Lightning")
    @pirate = @ship.create_pirate(catchphrase: "Don' botharrr talkin' like one, savvy?")
  end

  def test_should_still_work_without_an_associated_model
    @pirate.destroy
    @ship.reload.name = "The Vile Serpent"
    @ship.save
    assert_equal "The Vile Serpent", @ship.reload.name
  end

  def test_should_automatically_save_the_associated_model
    @ship.pirate.catchphrase = "Arr"
    @ship.save
    assert_equal "Arr", @ship.reload.pirate.catchphrase
  end

  def test_should_automatically_save_bang_the_associated_model
    @ship.pirate.catchphrase = "Arr"
    @ship.save!
    assert_equal "Arr", @ship.reload.pirate.catchphrase
  end

  def test_should_automatically_validate_the_associated_model
    @ship.pirate.catchphrase = ""
    assert_predicate @ship, :invalid?
    assert_predicate @ship.errors[:"pirate.catchphrase"], :any?
  end

  def test_should_merge_errors_on_the_associated_model_onto_the_parent_even_if_it_is_not_valid
    @ship.name = nil
    @ship.pirate.catchphrase = nil
    assert_predicate @ship, :invalid?
    assert_predicate @ship.errors[:name], :any?
    assert_predicate @ship.errors[:"pirate.catchphrase"], :any?
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_model
    @ship.pirate.catchphrase = ""
    @ship.name = ""
    @ship.save(validate: false)
    assert_equal ["", ""], [@ship.reload.name, @ship.pirate.catchphrase]
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @ship.pirate.catchphrase = ""
    assert_raise(ActiveRecord::RecordInvalid) do
      @ship.save!
    end
  end

  def test_should_not_save_and_return_false_if_a_callback_cancelled_saving
    ship = Ship.new(name: "The Vile Serpent")
    pirate = ship.build_pirate(catchphrase: "Arr")
    pirate.cancel_save_from_callback = true

    assert_no_difference "Ship.count" do
      assert_no_difference "Pirate.count" do
        assert_not ship.save
      end
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@ship.pirate.catchphrase, @ship.name]

    @ship.pirate.catchphrase = "Arr"
    @ship.name = "The Vile Serpent"

    # Stub the save method of the @ship.pirate instance to raise an exception
    class << @ship.pirate
      def save(**)
        super
        raise "Oh noes!"
      end
    end

    assert_raise(RuntimeError) { assert_not @ship.save }
    assert_equal before, [@ship.pirate.reload.catchphrase, @ship.reload.name]
  end

  def test_should_not_load_the_associated_model
    assert_queries_count(3) { @ship.name = "The Vile Serpent"; @ship.save! }
  end

  def test_should_save_with_non_nullable_foreign_keys
    parent = Post.new title: "foo", body: "..."
    child = parent.comments.build body: "..."
    child.save!
    assert_equal child.reload.post, parent.reload
  end

  def test_should_save_if_previously_saved
    ship = Ship.create(name: "Nights Dirty Lightning", pirate: Pirate.new(catchphrase: "Arrrr"))
    ship.create_pirate(catchphrase: "Savvy?")
    assert_equal "Savvy?", ship.reload.pirate.catchphrase
  end
end

module AutosaveAssociationOnACollectionAssociationTests
  def test_should_automatically_save_the_associated_models
    new_names = ["Grace OMalley", "Privateers Greed"]
    @pirate.public_send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    @pirate.save
    assert_equal new_names.sort, @pirate.reload.public_send(@association_name).map(&:name).sort
  end

  def test_should_automatically_save_bang_the_associated_models
    new_names = ["Grace OMalley", "Privateers Greed"]
    @pirate.public_send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    @pirate.save!
    assert_equal new_names.sort, @pirate.reload.public_send(@association_name).map(&:name).sort
  end

  def test_should_update_children_when_autosave_is_true_and_parent_is_new_but_child_is_not
    parrot = Parrot.create!(name: "Polly")
    parrot.name = "Squawky"
    pirate = Pirate.new(parrots: [parrot], catchphrase: "Arrrr")

    pirate.save!

    assert_equal "Squawky", parrot.reload.name
  end

  def test_should_not_update_children_when_parent_creation_with_no_reason
    parrot = Parrot.create!(name: "Polly")
    assert_equal 0, parrot.updated_count

    Pirate.create!(parrot_ids: [parrot.id], catchphrase: "Arrrr")
    assert_equal 0, parrot.reload.updated_count
  end

  def test_should_automatically_validate_the_associated_models
    @pirate.public_send(@association_name).each { |child| child.name = "" }

    assert_not_predicate @pirate, :valid?
    assert_equal ["can't be blank"], @pirate.errors["#{@association_name}.name"]
    assert_empty @pirate.errors[@association_name]
  end

  def test_should_not_use_default_invalid_error_on_associated_models
    @pirate.public_send(@association_name).build(name: "")

    assert_not_predicate @pirate, :valid?
    assert_equal ["can't be blank"], @pirate.errors["#{@association_name}.name"]
    assert_empty @pirate.errors[@association_name]
  end

  def test_should_default_invalid_error_from_i18n
    I18n.backend.store_translations(:en, activerecord: { errors: { models:
      { @associated_model_name.to_s.to_sym => { blank: "cannot be blank" } }
    } })

    @pirate.public_send(@association_name).build(name: "")

    assert_not_predicate @pirate, :valid?
    assert_equal ["cannot be blank"], @pirate.errors["#{@association_name}.name"]
    assert_equal ["#{@association_name.to_s.humanize} name cannot be blank"], @pirate.errors.full_messages
    assert_empty @pirate.errors[@association_name]
  ensure
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_should_merge_errors_on_the_associated_models_onto_the_parent_even_if_it_is_not_valid
    @pirate.public_send(@association_name).each { |child| child.name = "" }
    @pirate.catchphrase = nil

    assert_not_predicate @pirate, :valid?
    assert_equal ["can't be blank"], @pirate.errors["#{@association_name}.name"]
    assert_predicate @pirate.errors[:catchphrase], :any?
  end

  def test_should_allow_to_bypass_validations_on_the_associated_models_on_update
    @pirate.catchphrase = ""
    @pirate.public_send(@association_name).each { |child| child.name = "" }

    assert @pirate.save(validate: false)
    assert_equal ["", "", ""], [
      @pirate.reload.catchphrase,
      @pirate.public_send(@association_name).first.name,
      @pirate.public_send(@association_name).last.name
    ]
  end

  def test_should_validation_the_associated_models_on_create
    assert_no_difference("#{ @association_name == :birds ? 'Bird' : 'Parrot' }.count") do
      2.times { @pirate.public_send(@association_name).build }
      @pirate.save
    end
  end

  def test_should_allow_to_bypass_validations_on_the_associated_models_on_create
    assert_difference("#{ @association_name == :birds ? 'Bird' : 'Parrot' }.count", 2) do
      2.times { @pirate.public_send(@association_name).build }
      @pirate.save(validate: false)
    end
  end

  def test_should_not_save_and_return_false_if_a_callback_cancelled_saving_in_either_create_or_update
    @pirate.catchphrase = "Changed"
    @child_1.name = "Changed"
    @child_1.cancel_save_from_callback = true

    assert_not @pirate.save
    assert_equal "Don' botharrr talkin' like one, savvy?", @pirate.reload.catchphrase
    assert_equal "Posideons Killer", @child_1.reload.name

    new_pirate = Pirate.new(catchphrase: "Arr")
    new_child = new_pirate.public_send(@association_name).build(name: "Grace OMalley")
    new_child.cancel_save_from_callback = true

    assert_no_difference "Pirate.count" do
      assert_no_difference "#{new_child.class.name}.count" do
        assert_not new_pirate.save
      end
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@pirate.catchphrase, *@pirate.public_send(@association_name).map(&:name)]
    new_names = ["Grace OMalley", "Privateers Greed"]

    @pirate.catchphrase = "Arr"
    @pirate.public_send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    # Stub the save method of the first child instance to raise an exception
    class << @pirate.public_send(@association_name).first
      def save(**)
        super
        raise "Oh noes!"
      end
    end

    assert_raise(RuntimeError) { assert_not @pirate.save }
    assert_equal before, [@pirate.reload.catchphrase, *@pirate.send(@association_name).map(&:name)]
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @pirate.public_send(@association_name).each { |child| child.name = "" }
    assert_raise(ActiveRecord::RecordInvalid) do
      @pirate.save!
    end
  end

  def test_should_not_load_the_associated_models_if_they_were_not_loaded_yet
    assert_queries_count(3) { @pirate.catchphrase = "Arr"; @pirate.save! }

    @pirate.public_send(@association_name).load_target

    assert_queries_count(5) do
      @pirate.catchphrase = "Yarr"
      new_names = ["Grace OMalley", "Privateers Greed"]
      @pirate.public_send(@association_name).each_with_index { |child, i| child.name = new_names[i] }
      @pirate.save!
    end
  end
end

class TestAutosaveAssociationOnAHasManyAssociation < ActiveRecord::TestCase
  def setup
    super
    @association_name = :birds
    @associated_model_name = :bird

    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.birds.create(name: "Posideons Killer")
    @child_2 = @pirate.birds.create(name: "Killer bandita Dionne")
  end

  include AutosaveAssociationOnACollectionAssociationTests
end

class TestAutosaveAssociationOnAHasAndBelongsToManyAssociation < ActiveRecord::TestCase
  def setup
    super
    @association_name = :autosaved_parrots
    @associated_model_name = :parrot
    @habtm = true

    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.parrots.create(name: "Posideons Killer")
    @child_2 = @pirate.parrots.create(name: "Killer bandita Dionne")
  end

  include AutosaveAssociationOnACollectionAssociationTests
end

class TestAutosaveAssociationOnAHasAndBelongsToManyAssociationWithAcceptsNestedAttributes < ActiveRecord::TestCase
  def setup
    super
    @association_name = :parrots
    @associated_model_name = :parrot
    @habtm = true

    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.parrots.create(name: "Posideons Killer")
    @child_2 = @pirate.parrots.create(name: "Killer bandita Dionne")
  end

  include AutosaveAssociationOnACollectionAssociationTests
end

class TestAutosaveAssociationValidationsOnAHasManyAssociation < ActiveRecord::TestCase
  def setup
    super
    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @pirate.birds.create(name: "cookoo")

    @author = Author.new(name: "DHH")
    @author.published_books.build(name: "Rework", isbn: "1234")
    @author.published_books.build(name: "Remote", isbn: "1234")
  end

  test "should automatically validate associations" do
    assert_predicate @pirate, :valid?
    @pirate.birds.each { |bird| bird.name = "" }

    assert_not_predicate @pirate, :valid?
  end

  test "rollbacks whole transaction and raises ActiveRecord::RecordInvalid when associations fail to #save! due to uniqueness validation failure" do
    author_count_before_save = Author.count
    book_count_before_save = Book.count

    assert_no_difference "Author.count" do
      assert_no_difference "Book.count" do
        exception = assert_raises(ActiveRecord::RecordInvalid) do
          @author.save!
        end

        assert_equal("Validation failed: Published books is invalid", exception.message)
      end
    end

    assert_equal(author_count_before_save, Author.count)
    assert_equal(book_count_before_save, Book.count)
  end

  test "rollbacks whole transaction when associations fail to #save due to uniqueness validation failure" do
    author_count_before_save = Author.count
    book_count_before_save = Book.count

    assert_no_difference "Author.count" do
      assert_no_difference "Book.count" do
        assert_nothing_raised do
          result = @author.save

          assert_not(result)
        end
      end
    end

    assert_equal(author_count_before_save, Author.count)
    assert_equal(book_count_before_save, Book.count)
  end

  def test_validations_still_fire_on_unchanged_association_with_custom_validation_context
    pirate = FamousPirate.create!(catchphrase: "Avast Ye!")
    pirate.famous_ships.create!

    assert_predicate pirate, :valid?
    assert_not pirate.valid?(:conference)
  end
end

class TestAutosaveAssociationValidationsOnAHasOneAssociation < ActiveRecord::TestCase
  def setup
    super
    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @pirate.create_ship(name: "titanic")
    super
  end

  test "should automatically validate associations with :validate => true" do
    assert_predicate @pirate, :valid?
    @pirate.ship.name = ""
    assert_not_predicate @pirate, :valid?
  end

  test "should not automatically add validate associations without :validate => true" do
    assert_predicate @pirate, :valid?
    @pirate.non_validated_ship.name = ""
    assert_predicate @pirate, :valid?
  end
end

class TestAutosaveAssociationValidationsOnABelongsToAssociation < ActiveRecord::TestCase
  def setup
    super
    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
  end

  test "should automatically validate associations with :validate => true" do
    assert_predicate @pirate, :valid?
    @pirate.parrot = Parrot.new(name: "")
    assert_not_predicate @pirate, :valid?
  end

  test "should not automatically validate associations without :validate => true" do
    assert_predicate @pirate, :valid?
    @pirate.non_validated_parrot = Parrot.new(name: "")
    assert_predicate @pirate, :valid?
  end

  def test_validations_still_fire_on_unchanged_association_with_custom_validation_context
    firm_with_low_credit = Firm.create!(name: "Something", account: Account.new(credit_limit: 50))

    assert_predicate firm_with_low_credit, :valid?
    assert_not firm_with_low_credit.valid?(:bank_loan)
  end
end

class TestAutosaveAssociationValidationsOnAHABTMAssociation < ActiveRecord::TestCase
  def setup
    super
    @pirate = Pirate.create(catchphrase: "Don' botharrr talkin' like one, savvy?")
  end

  test "should automatically validate associations with :validate => true" do
    assert_predicate @pirate, :valid?
    @pirate.parrots = [ Parrot.new(name: "popuga") ]
    @pirate.parrots.each { |parrot| parrot.name = "" }
    assert_not_predicate @pirate, :valid?
  end

  test "should not automatically validate associations without :validate => true" do
    assert_predicate @pirate, :valid?
    @pirate.non_validated_parrots = [ Parrot.new(name: "popuga") ]
    @pirate.non_validated_parrots.each { |parrot| parrot.name = "" }
    assert_predicate @pirate, :valid?
  end
end

class TestAutosaveAssociationValidationMethodsGeneration < ActiveRecord::TestCase
  def setup
    super
    @pirate = Pirate.new
  end

  test "should generate validation methods for has_many associations" do
    assert_respond_to @pirate, :validate_associated_records_for_birds
  end

  test "should generate validation methods for has_one associations with :validate => true" do
    assert_respond_to @pirate, :validate_associated_records_for_ship
  end

  test "should not generate validation methods for has_one associations without :validate => true" do
    assert_not_respond_to @pirate, :validate_associated_records_for_non_validated_ship
  end

  test "should generate validation methods for belongs_to associations with :validate => true" do
    assert_respond_to @pirate, :validate_associated_records_for_parrot
  end

  test "should not generate validation methods for belongs_to associations without :validate => true" do
    assert_not_respond_to @pirate, :validate_associated_records_for_non_validated_parrot
  end

  test "should generate validation methods for HABTM associations with :validate => true" do
    assert_respond_to @pirate, :validate_associated_records_for_parrots
  end
end

class TestAutosaveAssociationWithTouch < ActiveRecord::TestCase
  def test_autosave_with_touch_should_not_raise_system_stack_error
    invoice = Invoice.create
    assert_nothing_raised { invoice.line_items.create(amount: 10) }
  end
end

class TestAutosaveAssociationOnAHasManyAssociationWithInverse < ActiveRecord::TestCase
  class Post < ActiveRecord::Base
    has_many :comments, inverse_of: :post
  end

  class Comment < ActiveRecord::Base
    belongs_to :post, inverse_of: :comments

    attr_accessor :post_comments_count
    after_save do
      self.post_comments_count = post.comments.count
    end
  end

  def setup
    Comment.delete_all
  end

  def test_after_save_callback_with_autosave
    post = Post.new(title: "Test", body: "...")
    comment = post.comments.build(body: "...")
    post.save!

    assert_equal 1, post.comments.count
    assert_equal 1, comment.post_comments_count
  end
end

class TestAutosaveAssociationOnAHasManyAssociationDefinedInSubclassWithAcceptsNestedAttributes < ActiveRecord::TestCase
  def test_should_update_children_when_association_redefined_in_subclass
    agency = Agency.create!(name: "Agency")
    valid_project = Project.create!(firm: agency, name: "Initial")
    agency.update!(
      "projects_attributes" => {
        "0" => {
          "name" => "Updated",
          "id" => valid_project.id
        }
      }
    )
    valid_project.reload

    assert_equal "Updated", valid_project.name
  end
end

class TestAutosaveAssociationOnABelongsToAssociationDefinedAsRecord < ActiveRecord::TestCase
  def test_should_not_raise_error
    translation = Translation.create(locale: "fr", key: "bread", value: "Baguette 🥖")
    author = Author.create(name: "Dorian Marié")
    translation.build_attachment(record: author)
    assert_nothing_raised do
      translation.save!
    end
  end
end
