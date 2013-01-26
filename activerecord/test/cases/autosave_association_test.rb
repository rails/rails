require 'cases/helper'
require 'models/bird'
require 'models/company'
require 'models/customer'
require 'models/developer'
require 'models/face'
require 'models/invoice'
require 'models/line_item'
require 'models/man'
require 'models/order'
require 'models/parrot'
require 'models/person'
require 'models/pirate'
require 'models/post'
require 'models/reader'
require 'models/ship'
require 'models/ship_part'
require 'models/tag'
require 'models/tagging'
require 'models/treasure'
require 'models/company'

class TestAutosaveAssociationsInGeneral < ActiveRecord::TestCase
  def test_autosave_should_be_a_valid_option_for_has_one
    assert base.valid_keys_for_has_one_association.include?(:autosave)
  end

  def test_autosave_should_be_a_valid_option_for_belongs_to
    assert base.valid_keys_for_belongs_to_association.include?(:autosave)
  end

  def test_autosave_should_be_a_valid_option_for_has_many
    assert base.valid_keys_for_has_many_association.include?(:autosave)
  end

  def test_autosave_should_be_a_valid_option_for_has_and_belongs_to_many
    assert base.valid_keys_for_has_and_belongs_to_many_association.include?(:autosave)
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

  private

  def base
    ActiveRecord::Base
  end

  def assert_no_difference_when_adding_callbacks_twice_for(model, association_name)
    reflection = model.reflect_on_association(association_name)
    assert_no_difference "callbacks_for_model(#{model.name}).length" do
      model.send(:add_autosave_association_callbacks, reflection)
    end
  end

  def callbacks_for_model(model)
    model.instance_variables.grep(/_callbacks$/).map do |ivar|
      model.instance_variable_get(ivar)
    end.flatten
  end
end

class TestDefaultAutosaveAssociationOnAHasOneAssociation < ActiveRecord::TestCase
  fixtures :companies, :accounts

  def test_should_save_parent_but_not_invalid_child
    firm = Firm.new(:name => 'GlobalMegaCorp')
    assert firm.valid?

    firm.build_account_using_primary_key
    assert !firm.build_account_using_primary_key.valid?

    assert firm.save
    assert firm.account_using_primary_key.new_record?
  end

  def test_save_fails_for_invalid_has_one
    firm = Firm.find(:first)
    assert firm.valid?

    firm.account = Account.new

    assert !firm.account.valid?
    assert !firm.valid?
    assert !firm.save
    assert_equal ["is invalid"], firm.errors["account"]
  end

  def test_save_succeeds_for_invalid_has_one_with_validate_false
    firm = Firm.find(:first)
    assert firm.valid?

    firm.unvalidated_account = Account.new

    assert !firm.unvalidated_account.valid?
    assert firm.valid?
    assert firm.save
  end

  def test_build_before_child_saved
    firm = Firm.find(1)

    account = firm.account.build("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.new_record?
    assert firm.save
    assert_equal account, firm.account
    assert !account.new_record?
  end

  def test_build_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.new_record?
    assert firm.save
    assert_equal account, firm.account
    assert !account.new_record?
  end

  def test_assignment_before_parent_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.find(1)
    assert firm.new_record?
    assert_equal a, firm.account
    assert firm.save
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_assignment_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.new("credit_limit" => 1000)
    assert firm.new_record?
    assert a.new_record?
    assert_equal a, firm.account
    assert firm.save
    assert !firm.new_record?
    assert !a.new_record?
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_not_resaved_when_unchanged
    firm = Firm.find(:first, :include => :account)
    firm.name += '-changed'
    assert_queries(1) { firm.save! }

    firm = Firm.find(:first)
    firm.account = Account.find(:first)
    assert_queries(Firm.partial_updates? ? 0 : 1) { firm.save! }

    firm = Firm.find(:first).clone
    firm.account = Account.find(:first)
    assert_queries(2) { firm.save! }

    firm = Firm.find(:first).clone
    firm.account = Account.find(:first).clone
    assert_queries(2) { firm.save! }
  end
end

class TestDefaultAutosaveAssociationOnABelongsToAssociation < ActiveRecord::TestCase
  fixtures :companies, :posts, :tags, :taggings

  def test_should_save_parent_but_not_invalid_child
    client = Client.new(:name => 'Joe (the Plumber)')
    assert client.valid?

    client.build_firm
    assert !client.firm.valid?

    assert client.save
    assert client.firm.new_record?
  end

  def test_save_fails_for_invalid_belongs_to
    # Oracle saves empty string as NULL therefore :message changed to one space
    assert log = AuditLog.create(:developer_id => 0, :message => " ")

    log.developer = Developer.new
    assert !log.developer.valid?
    assert !log.valid?
    assert !log.save
    assert_equal ["is invalid"], log.errors["developer"]
  end

  def test_save_succeeds_for_invalid_belongs_to_with_validate_false
    # Oracle saves empty string as NULL therefore :message changed to one space
    assert log = AuditLog.create(:developer_id => 0, :message=> " ")

    log.unvalidated_developer = Developer.new
    assert !log.unvalidated_developer.valid?
    assert log.valid?
    assert log.save
  end

  def test_assignment_before_parent_saved
    client = Client.find(:first)
    apple = Firm.new("name" => "Apple")
    client.firm = apple
    assert_equal apple, client.firm
    assert apple.new_record?
    assert client.save
    assert apple.save
    assert !apple.new_record?
    assert_equal apple, client.firm
    assert_equal apple, client.firm(true)
  end

  def test_assignment_before_either_saved
    final_cut = Client.new("name" => "Final Cut")
    apple = Firm.new("name" => "Apple")
    final_cut.firm = apple
    assert final_cut.new_record?
    assert apple.new_record?
    assert final_cut.save
    assert !final_cut.new_record?
    assert !apple.new_record?
    assert_equal apple, final_cut.firm
    assert_equal apple, final_cut.firm(true)
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
    tags(:misc).create_tagging(:taggable => posts(:thinking))
    assert_equal num_tagging + 1, Tagging.count
  end
end

class TestDefaultAutosaveAssociationOnAHasManyAssociation < ActiveRecord::TestCase
  fixtures :companies, :people

  def test_invalid_adding
    firm = Firm.find(1)
    assert !(firm.clients_of_firm << c = Client.new)
    assert c.new_record?
    assert !firm.valid?
    assert !firm.save
    assert c.new_record?
  end

  def test_invalid_adding_before_save
    no_of_firms = Firm.count
    no_of_clients = Client.count
    new_firm = Firm.new("name" => "A New Firm, Inc")
    new_firm.clients_of_firm.concat([c = Client.new, Client.new("name" => "Apple")])
    assert c.new_record?
    assert !c.valid?
    assert !new_firm.valid?
    assert !new_firm.save
    assert c.new_record?
    assert new_firm.new_record?
  end

  def test_invalid_adding_with_validate_false
    firm = Firm.find(:first)
    client = Client.new
    firm.unvalidated_clients_of_firm << client

    assert firm.valid?
    assert !client.valid?
    assert firm.save
    assert client.new_record?
  end

  def test_valid_adding_with_validate_false
    no_of_clients = Client.count

    firm = Firm.find(:first)
    client = Client.new("name" => "Apple")

    assert firm.valid?
    assert client.valid?
    assert client.new_record?

    firm.unvalidated_clients_of_firm << client

    assert firm.save
    assert !client.new_record?
    assert_equal no_of_clients + 1, Client.count
  end

  def test_invalid_build
    new_client = companies(:first_firm).clients_of_firm.build
    assert new_client.new_record?
    assert !new_client.valid?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert !companies(:first_firm).save
    assert new_client.new_record?
    assert_equal 1, companies(:first_firm).clients_of_firm(true).size
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
    assert !new_firm.new_record?
    assert !c.new_record?
    assert_equal new_firm, c.firm
    assert_equal no_of_firms + 1, Firm.count      # Firm was saved to database.
    assert_equal no_of_clients + 2, Client.count  # Clients were saved to database.

    assert_equal 2, new_firm.clients_of_firm.size
    assert_equal 2, new_firm.clients_of_firm(true).size
  end

  def test_assign_ids
    firm = Firm.new("name" => "Apple")
    firm.client_ids = [companies(:first_client).id, companies(:second_client).id]
    firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert firm.clients.include?(companies(:second_client))
  end

  def test_assign_ids_for_through_a_belongs_to
    post = Post.new(:title => "Assigning IDs works!", :body => "You heared it here first, folks!")
    post.person_ids = [people(:david).id, people(:michael).id]
    post.save
    post.reload
    assert_equal 2, post.people.length
    assert post.people.include?(people(:david))
  end

  def test_build_before_save
    company = companies(:first_firm)
    new_client = assert_no_queries { company.clients_of_firm.build("name" => "Another Client") }
    assert !company.clients_of_firm.loaded?

    company.name += '-changed'
    assert_queries(2) { assert company.save }
    assert !new_client.new_record?
    assert_equal 2, company.clients_of_firm(true).size
  end

  def test_build_many_before_save
    company = companies(:first_firm)
    new_clients = assert_no_queries { company.clients_of_firm.build([{"name" => "Another Client"}, {"name" => "Another Client II"}]) }

    company.name += '-changed'
    assert_queries(3) { assert company.save }
    assert_equal 3, company.clients_of_firm(true).size
  end

  def test_build_via_block_before_save
    company = companies(:first_firm)
    new_client = assert_no_queries { company.clients_of_firm.build {|client| client.name = "Another Client" } }
    assert !company.clients_of_firm.loaded?

    company.name += '-changed'
    assert_queries(2) { assert company.save }
    assert !new_client.new_record?
    assert_equal 2, company.clients_of_firm(true).size
  end

  def test_build_many_via_block_before_save
    company = companies(:first_firm)
    new_clients = assert_no_queries do
      company.clients_of_firm.build([{"name" => "Another Client"}, {"name" => "Another Client II"}]) do |client|
        client.name = "changed"
      end
    end

    company.name += '-changed'
    assert_queries(3) { assert company.save }
    assert_equal 3, company.clients_of_firm(true).size
  end

  def test_replace_on_new_object
    firm = Firm.new("name" => "New Firm")
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    assert firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert firm.clients.include?(Client.find_by_name("New Client"))
  end
end

class TestDefaultAutosaveAssociationOnNewRecord < ActiveRecord::TestCase
  def test_autosave_new_record_on_belongs_to_can_be_disabled_per_relationship
    new_account = Account.new("credit_limit" => 1000)
    new_firm = Firm.new("name" => "some firm")

    assert new_firm.new_record?
    new_account.firm = new_firm
    new_account.save!

    assert !new_firm.new_record?

    new_account = Account.new("credit_limit" => 1000)
    new_autosaved_firm = Firm.new("name" => "some firm")

    assert new_autosaved_firm.new_record?
    new_account.unautosaved_firm = new_autosaved_firm
    new_account.save!

    assert new_autosaved_firm.new_record?
  end

  def test_autosave_new_record_on_has_one_can_be_disabled_per_relationship
    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    assert account.new_record?
    firm.account = account
    firm.save!

    assert !account.new_record?

    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    firm.unautosaved_account = account

    assert account.new_record?
    firm.unautosaved_account = account
    firm.save!

    assert account.new_record?
  end

  def test_autosave_new_record_on_has_many_can_be_disabled_per_relationship
    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    assert account.new_record?
    firm.accounts << account

    firm.save!
    assert !account.new_record?

    firm = Firm.new("name" => "some firm")
    account = Account.new("credit_limit" => 1000)

    assert account.new_record?
    firm.unautosaved_accounts << account

    firm.save!
    assert account.new_record?
  end
end

class TestDestroyAsPartOfAutosaveAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(:name => 'Nights Dirty Lightning')
  end

  # reload
  def test_a_marked_for_destruction_record_should_not_be_be_marked_after_reload
    @pirate.mark_for_destruction
    @pirate.ship.mark_for_destruction

    assert !@pirate.reload.marked_for_destruction?
    assert !@pirate.ship.marked_for_destruction?
  end

  # has_one
  def test_should_destroy_a_child_association_as_part_of_the_save_transaction_if_it_was_marked_for_destroyal
    assert !@pirate.ship.marked_for_destruction?

    @pirate.ship.mark_for_destruction
    id = @pirate.ship.id

    assert @pirate.ship.marked_for_destruction?
    assert Ship.find_by_id(id)

    @pirate.save
    assert_nil @pirate.reload.ship
    assert_nil Ship.find_by_id(id)
  end

  def test_should_skip_validation_on_a_child_association_if_marked_for_destruction
    @pirate.ship.name = ''
    assert !@pirate.valid?

    @pirate.ship.mark_for_destruction
    @pirate.ship.expects(:valid?).never
    assert_difference('Ship.count', -1) { @pirate.save! }
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
      def save(*args)
        super
        destroy
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@pirate.save }
    assert_not_nil @pirate.reload.ship
  end

  # belongs_to
  def test_should_destroy_a_parent_association_as_part_of_the_save_transaction_if_it_was_marked_for_destroyal
    assert !@ship.pirate.marked_for_destruction?

    @ship.pirate.mark_for_destruction
    id = @ship.pirate.id

    assert @ship.pirate.marked_for_destruction?
    assert Pirate.find_by_id(id)

    @ship.save
    assert_nil @ship.reload.pirate
    assert_nil Pirate.find_by_id(id)
  end

  def test_should_skip_validation_on_a_parent_association_if_marked_for_destruction
    @ship.pirate.catchphrase = ''
    assert !@ship.valid?

    @ship.pirate.mark_for_destruction
    @ship.pirate.expects(:valid?).never
    assert_difference('Pirate.count', -1) { @ship.save! }
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
      def save(*args)
        super
        destroy
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@ship.save }
    assert_not_nil @ship.reload.pirate
  end

  # has_many & has_and_belongs_to
  %w{ parrots birds }.each do |association_name|
    define_method("test_should_destroy_#{association_name}_as_part_of_the_save_transaction_if_they_were_marked_for_destroyal") do
      2.times { |i| @pirate.send(association_name).create!(:name => "#{association_name}_#{i}") }

      assert !@pirate.send(association_name).any? { |child| child.marked_for_destruction? }

      @pirate.send(association_name).each { |child| child.mark_for_destruction }
      klass = @pirate.send(association_name).first.class
      ids = @pirate.send(association_name).map(&:id)

      assert @pirate.send(association_name).all? { |child| child.marked_for_destruction? }
      ids.each { |id| assert klass.find_by_id(id) }

      @pirate.save
      assert @pirate.reload.send(association_name).empty?
      ids.each { |id| assert_nil klass.find_by_id(id) }
    end

    define_method("test_should_skip_validation_on_the_#{association_name}_association_if_marked_for_destruction") do
      2.times { |i| @pirate.send(association_name).create!(:name => "#{association_name}_#{i}") }
      children = @pirate.send(association_name)

      children.each { |child| child.name = '' }
      assert !@pirate.valid?

      children.each do |child|
        child.mark_for_destruction
        child.expects(:valid?).never
      end
      assert_difference("#{association_name.classify}.count", -2) { @pirate.save! }
    end

    define_method("test_should_skip_validation_on_the_#{association_name}_association_if_destroyed") do
      @pirate.send(association_name).create!(:name => "#{association_name}_1")
      children = @pirate.send(association_name)

      children.each { |child| child.name = '' }
      assert !@pirate.valid?

      children.each { |child| child.destroy }
      assert @pirate.valid?
    end

    define_method("test_a_child_marked_for_destruction_should_not_be_destroyed_twice_while_saving_#{association_name}") do
      @pirate.send(association_name).create!(:name => "#{association_name}_1")
      children = @pirate.send(association_name)

      children.each { |child| child.mark_for_destruction }
      assert @pirate.save
      children.each { |child|
        class << child
          def destroy; raise "Should not be called" end
        end
      }
      assert @pirate.save
    end

    define_method("test_should_rollback_destructions_if_an_exception_occurred_while_saving_#{association_name}") do
      2.times { |i| @pirate.send(association_name).create!(:name => "#{association_name}_#{i}") }
      before = @pirate.send(association_name).map { |c| c.mark_for_destruction ; c }

      # Stub the destroy method of the the second child to raise an exception
      class << before.last
        def destroy(*args)
          super
          raise 'Oh noes!'
        end
      end

      assert_raise(RuntimeError) { assert !@pirate.save }
      assert_equal before, @pirate.reload.send(association_name)
    end

    # Add and remove callbacks tests for association collections.
    %w{ method proc }.each do |callback_type|
      define_method("test_should_run_add_callback_#{callback_type}s_for_#{association_name}") do
        association_name_with_callbacks = "#{association_name}_with_#{callback_type}_callbacks"

        pirate = Pirate.new(:catchphrase => "Arr")
        pirate.send(association_name_with_callbacks).build(:name => "Crowe the One-Eyed")

        expected = [
          "before_adding_#{callback_type}_#{association_name.singularize}_<new>",
          "after_adding_#{callback_type}_#{association_name.singularize}_<new>"
        ]

        assert_equal expected, pirate.ship_log
      end

      define_method("test_should_run_remove_callback_#{callback_type}s_for_#{association_name}") do
        association_name_with_callbacks = "#{association_name}_with_#{callback_type}_callbacks"

        @pirate.send(association_name_with_callbacks).create!(:name => "Crowe the One-Eyed")
        @pirate.send(association_name_with_callbacks).each { |c| c.mark_for_destruction }
        child_id = @pirate.send(association_name_with_callbacks).first.id

        @pirate.ship_log.clear
        @pirate.save

        expected = [
          "before_removing_#{callback_type}_#{association_name.singularize}_#{child_id}",
          "after_removing_#{callback_type}_#{association_name.singularize}_#{child_id}"
        ]

        assert_equal expected, @pirate.ship_log
      end
    end
  end
end

class TestAutosaveAssociationOnAHasOneAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(:name => 'Nights Dirty Lightning')
  end

  def test_should_still_work_without_an_associated_model
    @ship.destroy
    @pirate.reload.catchphrase = "Arr"
    @pirate.save
    assert_equal 'Arr', @pirate.reload.catchphrase
  end

  def test_should_automatically_save_the_associated_model
    @pirate.ship.name = 'The Vile Insanity'
    @pirate.save
    assert_equal 'The Vile Insanity', @pirate.reload.ship.name
  end

  def test_should_automatically_save_bang_the_associated_model
    @pirate.ship.name = 'The Vile Insanity'
    @pirate.save!
    assert_equal 'The Vile Insanity', @pirate.reload.ship.name
  end

  def test_should_automatically_validate_the_associated_model
    @pirate.ship.name = ''
    assert @pirate.invalid?
    assert @pirate.errors[:"ship.name"].any?
  end

  def test_should_merge_errors_on_the_associated_models_onto_the_parent_even_if_it_is_not_valid
    @pirate.ship.name   = nil
    @pirate.catchphrase = nil
    assert @pirate.invalid?
    assert @pirate.errors[:"ship.name"].any?
    assert @pirate.errors[:catchphrase].any?
  end

  def test_should_not_ignore_different_error_messages_on_the_same_attribute
    Ship.validates_format_of :name, :with => /\w/
    @pirate.ship.name   = ""
    @pirate.catchphrase = nil
    assert @pirate.invalid?
    assert_equal ["can't be blank", "is invalid"], @pirate.errors[:"ship.name"]
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_model
    @pirate.catchphrase = ''
    @pirate.ship.name = ''
    @pirate.save(:validate => false)
    # Oracle saves empty string as NULL
    if current_adapter?(:OracleAdapter)
      assert_equal [nil, nil], [@pirate.reload.catchphrase, @pirate.ship.name]
    else
      assert_equal ['', ''], [@pirate.reload.catchphrase, @pirate.ship.name]
    end
  end

  def test_should_allow_to_bypass_validations_on_associated_models_at_any_depth
    2.times { |i| @pirate.ship.parts.create!(:name => "part #{i}") }

    @pirate.catchphrase = ''
    @pirate.ship.name = ''
    @pirate.ship.parts.each { |part| part.name = '' }
    @pirate.save(:validate => false)

    values = [@pirate.reload.catchphrase, @pirate.ship.name, *@pirate.ship.parts.map(&:name)]
    # Oracle saves empty string as NULL
    if current_adapter?(:OracleAdapter)
      assert_equal [nil, nil, nil, nil], values
    else
      assert_equal ['', '', '', ''], values
    end
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @pirate.ship.name = ''
    assert_raise(ActiveRecord::RecordInvalid) do
      @pirate.save!
    end
  end

  def test_should_not_save_and_return_false_if_a_callback_cancelled_saving
    pirate = Pirate.new(:catchphrase => 'Arr')
    ship = pirate.build_ship(:name => 'The Vile Insanity')
    ship.cancel_save_from_callback = true

    assert_no_difference 'Pirate.count' do
      assert_no_difference 'Ship.count' do
        assert !pirate.save
      end
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@pirate.catchphrase, @pirate.ship.name]

    @pirate.catchphrase = 'Arr'
    @pirate.ship.name = 'The Vile Insanity'

    # Stub the save method of the @pirate.ship instance to raise an exception
    class << @pirate.ship
      def save(*args)
        super
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@pirate.save }
    assert_equal before, [@pirate.reload.catchphrase, @pirate.ship.name]
  end

  def test_should_not_load_the_associated_model
    assert_queries(1) { @pirate.catchphrase = 'Arr'; @pirate.save! }
  end
end

class TestAutosaveInverseAssociationOnAHasOneAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def test_should_save_the_inverse_association_model
    man = Man.new
    man.build_face
    man.face.save
  end
end

class TestAutosaveAssociationOnABelongsToAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @ship = Ship.create(:name => 'Nights Dirty Lightning')
    @pirate = @ship.create_pirate(:catchphrase => "Don' botharrr talkin' like one, savvy?")
  end

  def test_should_still_work_without_an_associated_model
    @pirate.destroy
    @ship.reload.name = "The Vile Insanity"
    @ship.save
    assert_equal 'The Vile Insanity', @ship.reload.name
  end

  def test_should_automatically_save_the_associated_model
    @ship.pirate.catchphrase = 'Arr'
    @ship.save
    assert_equal 'Arr', @ship.reload.pirate.catchphrase
  end

  def test_should_automatically_save_bang_the_associated_model
    @ship.pirate.catchphrase = 'Arr'
    @ship.save!
    assert_equal 'Arr', @ship.reload.pirate.catchphrase
  end

  def test_should_automatically_validate_the_associated_model
    @ship.pirate.catchphrase = ''
    assert @ship.invalid?
    assert @ship.errors[:"pirate.catchphrase"].any?
  end

  def test_should_merge_errors_on_the_associated_model_onto_the_parent_even_if_it_is_not_valid
    @ship.name = nil
    @ship.pirate.catchphrase = nil
    assert @ship.invalid?
    assert @ship.errors[:name].any?
    assert @ship.errors[:"pirate.catchphrase"].any?
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_model
    @ship.pirate.catchphrase = ''
    @ship.name = ''
    @ship.save(:validate => false)
    # Oracle saves empty string as NULL
    if current_adapter?(:OracleAdapter)
      assert_equal [nil, nil], [@ship.reload.name, @ship.pirate.catchphrase]
    else
      assert_equal ['', ''], [@ship.reload.name, @ship.pirate.catchphrase]
    end
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @ship.pirate.catchphrase = ''
    assert_raise(ActiveRecord::RecordInvalid) do
      @ship.save!
    end
  end

  def test_should_not_save_and_return_false_if_a_callback_cancelled_saving
    ship = Ship.new(:name => 'The Vile Insanity')
    pirate = ship.build_pirate(:catchphrase => 'Arr')
    pirate.cancel_save_from_callback = true

    assert_no_difference 'Ship.count' do
      assert_no_difference 'Pirate.count' do
        assert !ship.save
      end
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@ship.pirate.catchphrase, @ship.name]

    @ship.pirate.catchphrase = 'Arr'
    @ship.name = 'The Vile Insanity'

    # Stub the save method of the @ship.pirate instance to raise an exception
    class << @ship.pirate
      def save(*args)
        super
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@ship.save }
    assert_equal before, [@ship.pirate.reload.catchphrase, @ship.reload.name]
  end

  def test_should_not_load_the_associated_model
    assert_queries(1) { @ship.name = 'The Vile Insanity'; @ship.save! }
  end
end

module AutosaveAssociationOnACollectionAssociationTests
  def test_should_automatically_save_the_associated_models
    new_names = ['Grace OMalley', 'Privateers Greed']
    @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    @pirate.save
    assert_equal new_names, @pirate.reload.send(@association_name).map(&:name)
  end

  def test_should_automatically_save_bang_the_associated_models
    new_names = ['Grace OMalley', 'Privateers Greed']
    @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    @pirate.save!
    assert_equal new_names, @pirate.reload.send(@association_name).map(&:name)
  end

  def test_should_automatically_validate_the_associated_models
    @pirate.send(@association_name).each { |child| child.name = '' }

    assert !@pirate.valid?
    assert_equal ["can't be blank"], @pirate.errors["#{@association_name}.name"]
    assert @pirate.errors[@association_name].empty?
  end

  def test_should_not_use_default_invalid_error_on_associated_models
    @pirate.send(@association_name).build(:name => '')

    assert !@pirate.valid?
    assert_equal ["can't be blank"], @pirate.errors["#{@association_name}.name"]
    assert @pirate.errors[@association_name].empty?
  end

  def test_should_default_invalid_error_from_i18n
    I18n.backend.store_translations(:en, :activerecord => {:errors => { :models =>
      { @association_name.to_s.singularize.to_sym => { :blank => "cannot be blank" } }
    }})

    @pirate.send(@association_name).build(:name => '')

    assert !@pirate.valid?
    assert_equal ["cannot be blank"], @pirate.errors["#{@association_name}.name"]
    assert_equal ["#{@association_name.to_s.titleize} name cannot be blank"], @pirate.errors.full_messages
    assert @pirate.errors[@association_name].empty?
  ensure
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_should_merge_errors_on_the_associated_models_onto_the_parent_even_if_it_is_not_valid
    @pirate.send(@association_name).each { |child| child.name = '' }
    @pirate.catchphrase = nil

    assert !@pirate.valid?
    assert_equal ["can't be blank"], @pirate.errors["#{@association_name}.name"]
    assert @pirate.errors[:catchphrase].any?
  end

  def test_should_allow_to_bypass_validations_on_the_associated_models_on_update
    @pirate.catchphrase = ''
    @pirate.send(@association_name).each { |child| child.name = '' }

    assert @pirate.save(:validate => false)
    # Oracle saves empty string as NULL
    if current_adapter?(:OracleAdapter)
      assert_equal [nil, nil, nil], [
        @pirate.reload.catchphrase,
        @pirate.send(@association_name).first.name,
        @pirate.send(@association_name).last.name
      ]
    else
      assert_equal ['', '', ''], [
        @pirate.reload.catchphrase,
        @pirate.send(@association_name).first.name,
        @pirate.send(@association_name).last.name
      ]
    end
  end

  def test_should_validation_the_associated_models_on_create
    assert_no_difference("#{ @association_name == :birds ? 'Bird' : 'Parrot' }.count") do
      2.times { @pirate.send(@association_name).build }
      @pirate.save
    end
  end

  def test_should_allow_to_bypass_validations_on_the_associated_models_on_create
    assert_difference("#{ @association_name == :birds ? 'Bird' : 'Parrot' }.count", 2) do
      2.times { @pirate.send(@association_name).build }
      @pirate.save(:validate => false)
    end
  end

  def test_should_not_save_and_return_false_if_a_callback_cancelled_saving_in_either_create_or_update
    @pirate.catchphrase = 'Changed'
    @child_1.name = 'Changed'
    @child_1.cancel_save_from_callback = true

    assert !@pirate.save
    assert_equal "Don' botharrr talkin' like one, savvy?", @pirate.reload.catchphrase
    assert_equal "Posideons Killer", @child_1.reload.name

    new_pirate = Pirate.new(:catchphrase => 'Arr')
    new_child = new_pirate.send(@association_name).build(:name => 'Grace OMalley')
    new_child.cancel_save_from_callback = true

    assert_no_difference 'Pirate.count' do
      assert_no_difference "#{new_child.class.name}.count" do
        assert !new_pirate.save
      end
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@pirate.catchphrase, *@pirate.send(@association_name).map(&:name)]
    new_names = ['Grace OMalley', 'Privateers Greed']

    @pirate.catchphrase = 'Arr'
    @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    # Stub the save method of the first child instance to raise an exception
    class << @pirate.send(@association_name).first
      def save(*args)
        super
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@pirate.save }
    assert_equal before, [@pirate.reload.catchphrase, *@pirate.send(@association_name).map(&:name)]
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @pirate.send(@association_name).each { |child| child.name = '' }
    assert_raise(ActiveRecord::RecordInvalid) do
      @pirate.save!
    end
  end

  def test_should_not_load_the_associated_models_if_they_were_not_loaded_yet
    assert_queries(1) { @pirate.catchphrase = 'Arr'; @pirate.save! }

    @pirate.send(@association_name).class # hack to load the target

    assert_queries(3) do
      @pirate.catchphrase = 'Yarr'
      new_names = ['Grace OMalley', 'Privateers Greed']
      @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }
      @pirate.save!
    end
  end
end

class TestAutosaveAssociationOnAHasManyAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @association_name = :birds

    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.birds.create(:name => 'Posideons Killer')
    @child_2 = @pirate.birds.create(:name => 'Killer bandita Dionne')
  end

  include AutosaveAssociationOnACollectionAssociationTests
end

class TestAutosaveAssociationOnAHasAndBelongsToManyAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @association_name = :parrots
    @habtm = true

    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.parrots.create(:name => 'Posideons Killer')
    @child_2 = @pirate.parrots.create(:name => 'Killer bandita Dionne')
  end

  include AutosaveAssociationOnACollectionAssociationTests
end

class TestAutosaveAssociationValidationsOnAHasManyAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @pirate.birds.create(:name => 'cookoo')
  end

  test "should automatically validate associations" do
    assert @pirate.valid?
    @pirate.birds.each { |bird| bird.name = '' }

    assert !@pirate.valid?
  end
end

class TestAutosaveAssociationValidationsOnAHasOneAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @pirate.create_ship(:name => 'titanic')
  end

  test "should automatically validate associations with :validate => true" do
    assert @pirate.valid?
    @pirate.ship.name = ''
    assert !@pirate.valid?
  end

  test "should not automatically validate associations without :validate => true" do
    assert @pirate.valid?
    @pirate.non_validated_ship.name = ''
    assert @pirate.valid?
  end
end

class TestAutosaveAssociationValidationsOnABelongsToAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
  end

  test "should automatically validate associations with :validate => true" do
    assert @pirate.valid?
    @pirate.parrot = Parrot.new(:name => '')
    assert !@pirate.valid?
  end

  test "should not automatically validate associations without :validate => true" do
    assert @pirate.valid?
    @pirate.non_validated_parrot = Parrot.new(:name => '')
    assert @pirate.valid?
  end
end

class TestAutosaveAssociationValidationsOnAHABTMAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
  end

  test "should automatically validate associations with :validate => true" do
    assert @pirate.valid?
    @pirate.parrots = [ Parrot.new(:name => 'popuga') ]
    @pirate.parrots.each { |parrot| parrot.name = '' }
    assert !@pirate.valid?
  end

  test "should not automatically validate associations without :validate => true" do
    assert @pirate.valid?
    @pirate.non_validated_parrots = [ Parrot.new(:name => 'popuga') ]
    @pirate.non_validated_parrots.each { |parrot| parrot.name = '' }
    assert @pirate.valid?
  end
end

class TestAutosaveAssociationValidationMethodsGeneration < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.new
  end

  test "should generate validation methods for has_many associations" do
    assert_respond_to @pirate, :validate_associated_records_for_birds
  end

  test "should generate validation methods for has_one associations with :validate => true" do
    assert_respond_to @pirate, :validate_associated_records_for_ship
  end

  test "should not generate validation methods for has_one associations without :validate => true" do
    assert !@pirate.respond_to?(:validate_associated_records_for_non_validated_ship)
  end

  test "should generate validation methods for belongs_to associations with :validate => true" do
    assert_respond_to @pirate, :validate_associated_records_for_parrot
  end

  test "should not generate validation methods for belongs_to associations without :validate => true" do
    assert !@pirate.respond_to?(:validate_associated_records_for_non_validated_parrot)
  end

  test "should generate validation methods for HABTM associations with :validate => true" do
    assert_respond_to @pirate, :validate_associated_records_for_parrots
  end

  test "should not generate validation methods for HABTM associations without :validate => true" do
    assert !@pirate.respond_to?(:validate_associated_records_for_non_validated_parrots)
  end
end

class TestAutosaveAssociationWithTouch < ActiveRecord::TestCase
  def test_autosave_with_touch_should_not_raise_system_stack_error
    invoice = Invoice.create
    assert_nothing_raised { invoice.line_items.create(:amount => 10) }
  end
end
