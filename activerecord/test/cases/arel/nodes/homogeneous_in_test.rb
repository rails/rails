# frozen_string_literal: true

require_relative "../helper"
require "active_record/type_caster/map"
require "active_model"
class Arel::Nodes::HomogeneousInTest < Arel::Spec
  def test_in
    table = Arel::Table.new :users, type_caster: fake_pg_caster

    expr = Arel::Nodes::HomogeneousIn.new(["Bobby", "Robert"], table[:name], :in)

    _(expr.to_sql).must_be_like %{
      "users"."name" IN (?, ?)
    }
  end

  def test_custom_attribute_node
    table = Arel::Table.new :users, type_caster: fake_pg_caster

    node = TypedNode.new("COALESCE",
                         [table[:nickname], table[:name]],
                         STRING_TYPE
                        )
    expr = Arel::Nodes::HomogeneousIn.new(["Bobby", "Robert"], node, :in)

    _(expr.to_sql).must_be_like %{
      COALESCE("users"."nickname", "users"."name") IN (?, ?)
    }
  end

  private
    STRING_TYPE = ActiveModel::Type::String.new.freeze

    # this is a named function that also has a data type
    class TypedNode < Arel::Nodes::NamedFunction
      attr_reader :type_caster

      def initialize(name, expr, type)
        super(name, expr, nil)
        @type_caster = type
      end
    end

    # map that converts attribute names to a caster
    def fake_pg_caster
      Object.new.tap do |caster|
        def caster.type_for_attribute(attr_name)
          STRING_TYPE
        end
      end
    end
end
