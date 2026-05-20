# frozen_string_literal: true

require "active_record"
require "active_support/inflector"
require "logger"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# SQLite does not ship with this application-specific unaccent function.
# Defining it here keeps this demo executable while showing the SQL shape the
# application wants to generate.
ActiveRecord::Base.connection.raw_connection.create_function("custom_immutable_unaccent", 1) do |function, value|
  function.result = value.nil? ? nil : ActiveSupport::Inflector.transliterate(value)
end

# Marker type: this behaves like a normal string type for casting and storage.
# The query hooks below decide which predicates should be rendered with
# lower(custom_immutable_unaccent(...)).
class UncasedString < ActiveRecord::Type::String
  def query_attribute(attribute)
    normalize(attribute)
  end

  def query_value(attribute, value, predicate_builder:)
    normalize(predicate_builder.build_bind_attribute(attribute.name, value))
  end

  private
    def normalize(node)
      Arel::Nodes::NamedFunction.new(
        "lower",
        [Arel::Nodes::NamedFunction.new("custom_immutable_unaccent", [node])]
      )
    end
end

ActiveRecord::Schema.define do
  create_table :widgets, force: true do |t|
    t.string :name
    t.string :plain_name
  end
end

class Widget < ActiveRecord::Base
  attribute :name, UncasedString.new
end

Widget.create!(name: "FoO", plain_name: "FoO")
Widget.create!(name: "Bar", plain_name: "Bar")
Widget.create!(name: "BAZ", plain_name: "BAZ")
Widget.create!(name: "CAFÉ", plain_name: "CAFÉ")

queries = {
  equality: Widget.where(name: "foo"),
  accented_equality: Widget.where(name: "cafe"),
  not_equal: Widget.where.not(name: "foo"),
  in_list: Widget.where(name: ["foo", "baz"]),
  not_in_list: Widget.where.not(name: ["foo", "baz"]),
  range: Widget.where(name: "ba".."fz"),
  normal_string_column: Widget.where(plain_name: "foo"),
}

queries.each do |name, relation|
  puts "#{name}:"
  puts "  #{relation.to_sql}"
  puts "  matches: #{relation.pluck(:name).inspect}"
end

puts "stored values: #{Widget.order(:id).pluck(:name).inspect}"
