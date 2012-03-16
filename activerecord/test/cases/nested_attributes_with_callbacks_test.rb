require "cases/helper"
require "models/pirate"
require "models/bird"

class TestNestedAttributesWithCallbacksInterferingWithAssignment < ActiveRecord::TestCase
  Pirate.has_many(:birds_with_interfering_callback,
                  :class_name => "Bird",
                  :before_add => proc { |p,b|
                    @@add_callback_called << b
                    p.birds_with_interfering_callback.to_a
                  })
  Pirate.has_many(:birds_with_callback,
                  :class_name => "Bird",
                  :before_add => proc { |p,b| @@add_callback_called << b })

  Pirate.accepts_nested_attributes_for(:birds_with_interfering_callback,
                                       :birds_with_callback,
                                       :allow_destroy => true)

  def setup
    @@add_callback_called = []
    @expect_callbacks_for = []
    @pirate_with_two_birds = Pirate.new.tap do |pirate|
      pirate.catchphrase = "Don't call me!"
      pirate.birds_attributes = [{:name => 'Bird1'},{:name => 'Bird2'}]
      pirate.save!
    end
    @birds = @pirate_with_two_birds.birds.to_a
    @birds_attributes = @birds.map do |bird|
      bird.attributes.slice("id","name")
    end
  end

  def new_birds
    @pirate_with_two_birds.birds_with_callback.to_a - @birds
  end

  def new_bird_attributes
     [{'name' => "New Bird"}]
  end

  def bird2_deletion_attributes
    [{'id' => @birds[1].id.to_s, "_destroy" => true}]
  end

  def update_new_and_destroy_bird_attributes
    [{'id' => @birds[0].id.to_s, 'name' => 'New Name'},
     {'name' => "New Bird"},
     {'id' => @birds[1].id.to_s, "_destroy" => true}]
  end

  # Characterizing when :before_add callback is called
  test ":before_add called for new bird when not loaded" do
    assert_birds_with_callback_not_loaded
    assert_callback_called_for_new_bird_assignment
  end

  test ":before_add called for new bird when loaded" do
    @pirate_with_two_birds.birds_with_callback.load_target
    assert_callback_called_for_new_bird_assignment
  end

  def assert_callback_called_for_new_bird_assignment
    @pirate_with_two_birds.birds_with_callback_attributes = new_bird_attributes
    assert_equal(1,new_birds.size)
    assert_callback_called_for_new_birds
  end

  test ":before_add not called for identical assignment when not loaded" do
    assert_birds_with_callback_not_loaded
    assert_callback_not_called_for_identical_assignment
  end

  test ":before_add not called for identical assignment when loaded" do
    @pirate_with_two_birds.birds_with_callback.load_target
    assert_callback_not_called_for_identical_assignment
  end

  def assert_callback_not_called_for_identical_assignment
    @pirate_with_two_birds.birds_with_callback_attributes = @birds_attributes
    assert_equal([],new_birds)
    assert_callback_called_for_new_birds
  end

  test ":before_add not called for destroy assignment when not loaded" do
    assert_birds_with_callback_not_loaded
    assert_callback_not_called_for_destroy_assignment
  end

  test ":before_add not called for destroy assignment when loaded" do
    @pirate_with_two_birds.birds_with_callback.load_target
    assert_callback_not_called_for_destroy_assignment
  end

  def assert_callback_not_called_for_destroy_assignment
    @pirate_with_two_birds.birds_with_callback_attributes =
      bird2_deletion_attributes
    assert_callback_called_for_new_birds
  end

  def assert_birds_with_callback_not_loaded
    assert_equal(false,@pirate_with_two_birds.birds_with_callback.loaded?)
  end

  def assert_callback_called_for_new_birds
    assert_equal(new_birds,@@add_callback_called)
  end

  # Ensuring that the records in the association target are updated,
  # whether the association is loaded before or not
  test "Assignment updates records in target when not loaded" do
    assert_equal(false,@pirate_with_two_birds.birds_with_callback.loaded?)
    assert_assignment_affects_records_in_target(:birds_with_callback)
  end

  test "Assignment updates records in target when loaded" do
    @pirate_with_two_birds.birds_with_callback.load_target
    assert_assignment_affects_records_in_target(:birds_with_callback)
  end

  test("Assignment updates records in target when not loaded" +
       " and callback loads target") do
    assert_equal(false,
                 @pirate_with_two_birds.birds_with_interfering_callback.loaded?)
    assert_assignment_affects_records_in_target(
     :birds_with_interfering_callback)
  end

  test("Assignment updates records in target when loaded" +
       " and callback loads target") do
    @pirate_with_two_birds.birds_with_interfering_callback.load_target
    assert_assignment_affects_records_in_target(
     :birds_with_interfering_callback)
  end

  def assert_assignment_affects_records_in_target(association_name)
    @pirate_with_two_birds.send("#{association_name}_attributes=",
                                update_new_and_destroy_bird_attributes)
    association = @pirate_with_two_birds.send(association_name)
    birds_in_target = @birds.map { |b| association.detect { |b_in_t| b_in_t == b }}
    assert_equal(true,birds_in_target[0].name_changed?,'First record not changed')
    assert_equal(true,birds_in_target[1].marked_for_destruction?,
                 'Second record not marked for destruction')
  end
end
