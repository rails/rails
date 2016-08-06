require "cases/helper"

class RequiredAssociationsTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class Parent < ActiveRecord::Base
  end

  class Child < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :parents, force: true
    @connection.create_table :children, force: true do |t|
      t.belongs_to :parent
    end
  end

  teardown do
    @connection.drop_table "parents", if_exists: true
    @connection.drop_table "children", if_exists: true
  end

  test "belongs_to associations are not required by default" do
    model = subclass_of(Child) do
      belongs_to :parent, inverse_of: false,
        class_name: "RequiredAssociationsTest::Parent"
    end

    assert model.new.save
    assert model.new(parent: Parent.new).save
  end

  test "required belongs_to associations have presence validated" do
    model = subclass_of(Child) do
      belongs_to :parent, required: true, inverse_of: false,
        class_name: "RequiredAssociationsTest::Parent"
    end

    record = model.new
    assert_not record.save
    assert_equal ["Parent must exist"], record.errors.full_messages

    record.parent = Parent.new
    assert record.save
  end

  test "has_one associations are not required by default" do
    model = subclass_of(Parent) do
      has_one :child, inverse_of: false,
        class_name: "RequiredAssociationsTest::Child"
    end

    assert model.new.save
    assert model.new(child: Child.new).save
  end

  test "required has_one associations have presence validated" do
    model = subclass_of(Parent) do
      has_one :child, required: true, inverse_of: false,
        class_name: "RequiredAssociationsTest::Child"
    end

    record = model.new
    assert_not record.save
    assert_equal ["Child must exist"], record.errors.full_messages

    record.child = Child.new
    assert record.save
  end

  test "required has_one associations have a correct error message" do
    model = subclass_of(Parent) do
      has_one :child, required: true, inverse_of: false,
      class_name: "RequiredAssociationsTest::Child"
    end

    record = model.create
    assert_equal ["Child must exist"], record.errors.full_messages
  end

  test "required belongs_to associations have a correct error message" do
    model = subclass_of(Child) do
      belongs_to :parent, required: true, inverse_of: false,
      class_name: "RequiredAssociationsTest::Parent"
    end

    record = model.create
    assert_equal ["Parent must exist"], record.errors.full_messages
  end

  private

  def subclass_of(klass, &block)
    subclass = Class.new(klass, &block)
    def subclass.name
      superclass.name
    end
    subclass
  end
end
