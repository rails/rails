# frozen_string_literal: true

require "active_record"
require "active_support/test_case"
require "active_support/testing/ractors_assertions"
require "weakref"

class AssociationRouteCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  # Ruby 3.3 doesn't reliably release these objects
  if RUBY_VERSION >= "3.4"
    def test_discarded_reflections_release_their_routes
      owner, destination = build_model, build_model
      origin = Class.new(owner)
      refs = Thread.new do
        reflection = ActiveRecord::Reflection::HasManyReflection.new(:children, nil,
          { anonymous_class: destination, foreign_key: "owner_id", primary_key: "id", inverse_of: false }, owner)
        route = reflection.association_route(origin_class: origin, destination_class: destination)
        { reflection: WeakRef.new(reflection), route: WeakRef.new(route) }
      end.value

      collect
      refs.each { |name, ref| assert_not ref.weakref_alive?, "#{name} was not collected" }
    end

    def test_live_reflections_release_replaced_schema_contexts
      reflection, owner, destination = build_reflection
      origin = Class.new(owner)
      ref = Thread.new do
        reflection.association_route(origin_class: origin, destination_class: destination)
        replaced = WeakRef.new(origin.schema_context)
        origin.reload_stub_schema(ActiveModel::Type::Integer)
        replaced
      end.value

      collect
      assert_not ref.weakref_alive?, "replaced schema context was not collected"
    end
  end

  def test_belongs_to_routes_follow_destination_schema_contexts
    owner, destination = build_model, build_model
    reflection = ActiveRecord::Reflection::BelongsToReflection.new(:parent, nil,
      { anonymous_class: destination, foreign_key: "parent_id", primary_key: "id", inverse_of: false }, owner)
    owner._reflections = { parent: reflection }.freeze
    route = reflection.association_route

    destination.reload_stub_schema(ActiveModel::Type::Integer)

    assert_equal route, reflection.association_route
    assert_not_same route, reflection.association_route
  end

  def test_dup_and_clear_do_not_share_reflection_caches
    reflection, _, destination = build_reflection
    copy = reflection.dup
    original_route = reflection.association_route
    copied_route = copy.association_route

    assert_equal original_route, copied_route
    assert_not_same original_route, copied_route

    reflection.clear_association_scope_cache(destination)

    assert_not_same original_route, reflection.association_route
    assert_same copied_route, copy.association_route
  end

  def test_clear_rebuilds_default_and_inherited_routes
    reflection, owner, destination = build_reflection
    origin = Class.new(owner)
    default_route = reflection.association_route
    inherited_route = reflection.association_route(origin_class: origin, destination_class: destination)

    reflection.clear_association_scope_cache(destination)

    assert_equal default_route, reflection.association_route
    assert_not_same default_route, reflection.association_route
    assert_equal inherited_route, reflection.association_route(origin_class: origin, destination_class: destination)
    assert_not_same inherited_route, reflection.association_route(origin_class: origin, destination_class: destination)
  end

  def test_live_owners_preserve_warm_values_across_gc
    reflection, owner, destination = build_reflection
    origin = Class.new(owner)
    route = reflection.association_route(origin_class: origin, destination_class: destination)
    default_route = reflection.association_route

    collect

    assert_same route, reflection.association_route(origin_class: origin, destination_class: destination)
    assert_same default_route, reflection.association_route
  end

  def test_threads_share_warm_values
    reflection, _, _ = build_reflection
    warm_route = reflection.association_route
    routes = 4.times.map { Thread.new { reflection.association_route } }.map(&:value)

    routes.each { |route| assert_same warm_route, route }
  end

  def test_overlapping_route_construction_produces_equivalent_routes
    reflection, _, _ = build_reflection
    resolve = reflection.method(:resolve_association_route)
    entered, release = Queue.new, Queue.new
    reflection.define_singleton_method(:resolve_association_route) do |*args|
      entered << true
      release.pop
      resolve.call(*args)
    end
    threads = Array.new(4) { Thread.new { reflection.association_route } }
    4.times { entered.pop }
    4.times { release << true }
    routes = threads.map(&:value)

    routes.each { |route| assert_equal routes.first, route }
    assert_equal [["id", "owner_id"]], routes.first.each_match.to_a
    assert_equal routes.first, reflection.association_route
  end

  if RUBY_VERSION >= "4.0"
    def test_shared_reflections_serve_their_default_route_to_other_ractors
      reflection, owner, destination = build_reflection
      origin = Class.new(owner)
      route = reflection.association_route
      ActiveSupport::Ractors.make_shareable(reflection)
      ActiveSupport::Ractors.make_shareable(route)
      assert_ractor_shareable reflection
      assert_ractor_shareable route

      shared, pairs, inherited_pairs = on_ractor(reflection, route, origin, destination) do |reflection, route, origin, destination|
        default = reflection.association_route
        inherited = reflection.association_route(origin_class: origin, destination_class: destination)
        [default.equal?(route), default.each_match.to_a, inherited.each_match.to_a]
      end

      assert shared
      assert_equal [["id", "owner_id"]], pairs
      assert_equal [["id", "owner_id"]], inherited_pairs
      assert_same route, reflection.association_route
    end
  end

  private
    # Like the schema context it stands in for, each stub is a distinct object
    # that refers to its model.
    class SchemaContextStub
      def initialize(model_class)
        @model_class = model_class
        freeze
      end
    end

    def build_model
      Class.new(ActiveRecord::Base) do
        self.primary_key = "id"
        def self.name = "CacheRouteModel"

        def self.inherited(subclass)
          super
          subclass.reload_stub_schema(@stub_type_class)
        end

        def self.reload_stub_schema(type_class)
          @stub_type_class = type_class
          @stub_schema_context = SchemaContextStub.new(self)
        end

        def self.schema_context = @stub_schema_context
        def self.current_schema_context = @stub_schema_context
        def self.type_for_attribute(_name) = @stub_type_class.new

        reload_stub_schema(ActiveModel::Type::Integer)
      end
    end

    def build_reflection
      owner, destination = build_model, build_model
      reflection = ActiveRecord::Reflection::HasManyReflection.new(:children, nil,
        { anonymous_class: destination, foreign_key: "owner_id", primary_key: "id", inverse_of: false }, owner)
      owner._reflections = { children: reflection }.freeze
      [reflection, owner, destination]
    end

    def collect
      4.times { GC.start(full_mark: true, immediate_sweep: true) }
    end
end
