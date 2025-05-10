# frozen_string_literal: true

require "abstract_unit"

class Item
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :integer
  attribute :name, :string

  def to_param
    id
  end

  def self.find(id)
    new(id: id)
  end
end

class FieldIdTest < ActionView::TestCase
  def test_form_builder_field_id_without_index
    item = Item.new(id: 1)
    render inline: <<~ERB, locals: { item: }
      <%= fields_for("items[]", item) do |form| %>
        <%= form.hidden_field :name %>
        <p><%= form.field_id :name %></p>
      <% end %>
    ERB

    hidden_field = rendered.html.at("input")
    p_tag = rendered.html.at("p")

    assert_equal hidden_field["id"], p_tag.text
  end

  def test_form_builder_field_id_with_index
    item = Item.new(id: 1)
    render inline: <<~ERB, locals: { item: }
      <%= fields_for("items", item, index: item.id) do |form| %>
        <%= form.hidden_field :name %>
        <p><%= form.field_id :name %></p>
      <% end %>
    ERB

    hidden_field = rendered.html.at("input")
    p_tag = rendered.html.at("p")

    assert_equal hidden_field["id"], p_tag.text
  end

  def test_bug_report_example
    render inline: <<~ERB
      <%= fields_for("items[]", Item.find(1)) do |form| %>
        <%= form.field_id :name %>
      <% end %>
    ERB

    assert_equal "items_1_name", rendered.strip
  end
end
