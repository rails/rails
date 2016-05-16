require "cases/helper"
require "models/pirate"
require "models/bird"

class TestNestedAttributesWithCallbacksInterferingWithAssignment < ActiveRecord::TestCase
  fixtures :pirates

  def setup
    @add_callback_called = []
    @expect_callbacks_for = []
    Pirate.has_many :birds_with_interfering_callback, :class_name => "Bird",:before_add => proc { |p,b| @add_callback_called << b; p.birds_with_interfering_callback.to_a }
    Pirate.has_many :birds_with_non_interfering_callback, :class_name => "Bird",:before_add => proc { |p,b| @add_callback_called << b }
    Pirate.accepts_nested_attributes_for :birds_with_interfering_callback,:birds_with_non_interfering_callback, :allow_destroy => true
    @pirate_with_more_than_one_bird = pirates(:blackbeard)
    @pirate_with_more_than_one_bird.birds_attributes = [{:name => 'Bird1'},{:name => 'Bird2'}]
    @pirate_with_more_than_one_bird.save!
    @birds = @pirate_with_more_than_one_bird.birds.all
    @birds_attributes = @pirate_with_more_than_one_bird.birds.map { |bird| bird.attributes.slice("id","name") }
    @birds_attributes.first["name"] = "First Bird"
    @birds_attributes.last["_destroy"] = true
  end

  def assert_deletes_last_bird_and_calls_callback_before_add_for_new_birds(association_name,bird_count_difference)
    assert_difference('Bird.count',bird_count_difference) do
      @pirate_with_more_than_one_bird.update_attributes("#{association_name}_attributes" => @birds_attributes)
    end
    new_birds = @pirate_with_more_than_one_bird.birds.all - @birds
    assert_equal(new_birds,@add_callback_called,"Add should only be called when not already part of the association")    
  end

  test "Assignment to nested attributes without callbacks deletes last bird and does not callback before_add" do
    assert_deletes_last_bird_and_calls_callback_before_add_for_new_birds(:birds_with_non_interfering_callback,-1)
  end

  test "Assignment to nested attributes with callbacks deletes last bird and does not callback before_add" do
    assert_deletes_last_bird_and_calls_callback_before_add_for_new_birds(:birds_with_interfering_callback,-1)
  end

  def setup_new_bird
    @birds_attributes.unshift({:name => "New Bird"})
  end

  test "Assignment to nested attributes without callbacks deletes last bird and calls before_add for new bird" do
    setup_new_bird
    assert_deletes_last_bird_and_calls_callback_before_add_for_new_birds(:birds_with_non_interfering_callback,0)
  end

  test "Assignment to nested attributes with callbacks deletes last bird and calls before_add for new bird" do
    setup_new_bird
    assert_deletes_last_bird_and_calls_callback_before_add_for_new_birds(:birds_with_interfering_callback,0)
  end

end
