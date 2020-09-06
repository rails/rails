# frozen_string_literal: true

require 'cases/helper'
require 'models/pirate'
require 'models/bird'

class NestedAttributesWithCallbacksTest < ActiveRecord::TestCase
  Pirate.has_many(:birds_with_add_load,
                  class_name: 'Bird',
                  before_add: proc { |p, b|
                    @@add_callback_called << b
                    p.birds_with_add_load.to_a
                  })
  Pirate.has_many(:birds_with_add,
                  class_name: 'Bird',
                  before_add: proc { |p, b| @@add_callback_called << b })

  Pirate.accepts_nested_attributes_for(:birds_with_add_load,
                                       :birds_with_add,
                                       allow_destroy: true)

  def setup
    @@add_callback_called = []
    @pirate = Pirate.new.tap do |pirate|
      pirate.catchphrase = "Don't call me!"
      pirate.birds_attributes = [{ name: 'Bird1' }, { name: 'Bird2' }]
      pirate.save!
    end
    @birds = @pirate.birds.to_a
  end

  def bird_to_update
    @birds[0]
  end

  def bird_to_destroy
    @birds[1]
  end

  def existing_birds_attributes
    @birds.map do |bird|
      bird.attributes.slice('id', 'name')
    end
  end

  def new_birds
    @pirate.birds_with_add.to_a - @birds
  end

  def new_bird_attributes
    [{ 'name' => 'New Bird' }]
  end

  def destroy_bird_attributes
    [{ 'id' => bird_to_destroy.id.to_s, '_destroy' => true }]
  end

  def update_new_and_destroy_bird_attributes
    [{ 'id' => @birds[0].id.to_s, 'name' => 'New Name' },
     { 'name' => 'New Bird' },
     { 'id' => bird_to_destroy.id.to_s, '_destroy' => true }]
  end

  # Characterizing when :before_add callback is called
  test ':before_add called for new bird when not loaded' do
    assert_not_predicate @pirate.birds_with_add, :loaded?
    @pirate.birds_with_add_attributes = new_bird_attributes
    assert_new_bird_with_callback_called
  end

  test ':before_add called for new bird when loaded' do
    @pirate.birds_with_add.load_target
    @pirate.birds_with_add_attributes = new_bird_attributes
    assert_new_bird_with_callback_called
  end

  def assert_new_bird_with_callback_called
    assert_equal(1, new_birds.size)
    assert_equal(new_birds, @@add_callback_called)
  end

  test ':before_add not called for identical assignment when not loaded' do
    assert_not_predicate @pirate.birds_with_add, :loaded?
    @pirate.birds_with_add_attributes = existing_birds_attributes
    assert_callbacks_not_called
  end

  test ':before_add not called for identical assignment when loaded' do
    @pirate.birds_with_add.load_target
    @pirate.birds_with_add_attributes = existing_birds_attributes
    assert_callbacks_not_called
  end

  test ':before_add not called for destroy assignment when not loaded' do
    assert_not_predicate @pirate.birds_with_add, :loaded?
    @pirate.birds_with_add_attributes = destroy_bird_attributes
    assert_callbacks_not_called
  end

  test ':before_add not called for deletion assignment when loaded' do
    @pirate.birds_with_add.load_target
    @pirate.birds_with_add_attributes = destroy_bird_attributes
    assert_callbacks_not_called
  end

  def assert_callbacks_not_called
    assert_empty new_birds
    assert_empty @@add_callback_called
  end

  # Ensuring that the records in the association target are updated,
  # whether the association is loaded before or not
  test 'Assignment updates records in target when not loaded' do
    assert_not_predicate @pirate.birds_with_add, :loaded?
    @pirate.birds_with_add_attributes = update_new_and_destroy_bird_attributes
    assert_assignment_affects_records_in_target(:birds_with_add)
  end

  test 'Assignment updates records in target when loaded' do
    @pirate.birds_with_add.load_target
    @pirate.birds_with_add_attributes = update_new_and_destroy_bird_attributes
    assert_assignment_affects_records_in_target(:birds_with_add)
  end

  test('Assignment updates records in target when not loaded' \
       ' and callback loads target') do
    assert_not_predicate @pirate.birds_with_add_load, :loaded?
    @pirate.birds_with_add_load_attributes = update_new_and_destroy_bird_attributes
    assert_assignment_affects_records_in_target(:birds_with_add_load)
  end

  test('Assignment updates records in target when loaded' \
       ' and callback loads target') do
    @pirate.birds_with_add_load.load_target
    @pirate.birds_with_add_load_attributes = update_new_and_destroy_bird_attributes
    assert_assignment_affects_records_in_target(:birds_with_add_load)
  end

  def assert_assignment_affects_records_in_target(association_name)
    association = @pirate.send(association_name)
    assert association.detect { |b| b == bird_to_update }.name_changed?,
      'Update record not updated'
    assert association.detect { |b| b == bird_to_destroy }.marked_for_destruction?,
      'Destroy record not marked for destruction'
  end
end
