# :markup: markdown
# frozen_string_literal: true

require "active_support/weak_key_map"

module ActiveRecord
  # An association's writable foreign-key reference and query-only constraints,
  # oriented from the record holding the foreign key to the referenced record.
  class AssociationLink # :nodoc:
    EMPTY_FIXED_VALUES = {}.freeze
    private_constant :EMPTY_FIXED_VALUES

    attr_reader :reference, :reference_key, :constraints, :match

    # Attributes written alongside the foreign key, such as a polymorphic type.
    attr_reader :fixed_values

    def initialize(reference: nil, reference_key: reference&.reference_key, constraints: Key::Mapping.empty, fixed_values: EMPTY_FIXED_VALUES)
      @reference = reference
      @reference_key = reference_key
      @constraints = constraints
      @fixed_values = fixed_values.freeze
      @match = (constraints + reference).normalize if reference
      @hash = [reference, reference_key, constraints, @fixed_values].hash
      freeze
    end

    def ==(other)
      other.is_a?(AssociationLink) &&
        reference == other.reference &&
        reference_key == other.reference_key &&
        constraints == other.constraints &&
        fixed_values == other.fixed_values
    end
    alias_method :eql?, :==

    attr_reader :hash
  end

  # A link from an owner (origin) to its associated record (destination).
  # Keys stay as declared names; aliases are resolved on use against the
  # record or model being accessed.
  class AssociationRoute # :nodoc:
    EMPTY_FIXED_VALUES = {}.freeze
    EMPTY_KEY_PAIRS = [].freeze
    private_constant :EMPTY_FIXED_VALUES, :EMPTY_KEY_PAIRS

    class Cache < ActiveSupport::WeakKeyMap # :nodoc:
      NIL_KEY = Object.new.freeze
      private_constant :NIL_KEY

      def self.for(key)
        registry = ActiveSupport::Ractors.store_if_absent(:active_record_association_route_caches) { new }
        registry.fetch_or_store(key) { new }
      end

      def self.clear(key)
        ActiveSupport::Ractors[:active_record_association_route_caches]&.delete(key)
      end

      def fetch_or_store(key)
        super(key.nil? ? NIL_KEY : key)
      end
    end

    attr_reader :link

    def initialize(link:)
      @link = link
      initialize_keys
      @key_pairs = pairs_for(origin_key, destination_key)
      @reference_pairs = if link.constraints.empty?
        @key_pairs
      else
        pairs_for(reference_origin_key, reference_destination_key)
      end
      @hash = [self.class, link].hash
      freeze
    end

    def ==(other)
      other.class == self.class && link == other.link
    end
    alias_method :eql?, :==

    attr_reader :hash

    attr_reader :origin_key, :destination_key, :reference_origin_key, :reference_destination_key

    def predicate_accepts_bare_id?
      !origin_key.composite? && !reference_origin_key.composite?
    end

    def each_match(&block)
      @key_pairs.each(&block)
    end

    def each_reference(&block)
      @reference_pairs.each(&block)
    end

    def each_constraint(&block)
      @constraint_pairs.each(&block)
    end

    def origin_fixed_values
      @link.fixed_values
    end

    def destination_fixed_values
      EMPTY_FIXED_VALUES
    end

    private
      def initialize_keys
        @origin_key = link.match&.reference_key
        @destination_key = link.match&.target_key
        @reference_origin_key = link.reference_key
        @reference_destination_key = link.reference&.target_key
        @constraint_pairs = link.constraints.empty? ? EMPTY_KEY_PAIRS : pairs_for(link.constraints.reference_key, link.constraints.target_key)
      end

      def pairs_for(origin_key, destination_key)
        origin_key.zip(destination_key).map!(&:freeze).freeze if origin_key && destination_key
      end
  end

  class AssociationRoute::Reverse < AssociationRoute # :nodoc:
    def origin_fixed_values
      EMPTY_FIXED_VALUES
    end

    def destination_fixed_values
      @link.fixed_values
    end

    private
      def initialize_keys
        @origin_key = link.match&.target_key
        @destination_key = link.match&.reference_key
        @reference_origin_key = link.reference&.target_key
        @reference_destination_key = link.reference_key
        @constraint_pairs = link.constraints.empty? ? EMPTY_KEY_PAIRS : pairs_for(link.constraints.target_key, link.constraints.reference_key)
      end
  end
end
