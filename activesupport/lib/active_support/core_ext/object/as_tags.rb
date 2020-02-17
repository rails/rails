# frozen_string_literal: true

require "active_support/core_ext/object/blank"

class Object
  # +as_tags+ accumulates and returns a flat array of nonblank strings representing
  # an object.
  #
  # When called on an +Enumerable+, each element has +as_tags+ called in turn. When
  # called on a +Hash+, keys for truthy values will append their tags, leading to an
  # expressive optionality.
  #
  # +nil+, +false+, and blank strings, will not append themselves to the accumulator.
  #
  # ==== Examples
  #
  #  [:red, nil, [false, "bold", 123]].as_tags
  #  # => ["red", "bold", "123"]
  #
  #  {
  #    overdue: delivery_date.past?,
  #    international: origin.country != destination.country,
  #    priority: customer.vip?
  #  }.as_tags
  #  # => ["overdue", "priority"]
  #
  # The {tag and class_names helpers}[rdoc-ref:ActionView::Helpers::TagHelper] are both implemented using +as_tags+:
  #
  #  tag.button "Resolve", class: [
  #    "font-bold", "py-2", "px-4", "rounded",
  #    %w(bg-red-500 text-white) => model.alert_state?,
  #    %w(bg-blue-500 text-white) => model.normal_state?,
  #    %w(opacity-50 cursor-not-allowed) => model.readonly?
  #  ]
  #  # => '<button class="font-bold py-2 px-4 rounded bg-red-500 text-white">Resolve</button>'
  #
  # ==== Extending
  #
  # Any object may implement +as_tags+.  This is ideally in terms of delegating +as_tags+ in
  # turn to collaborators:
  #
  #  class Topic < ApplicationRecord
  #    has_and_belongs_to_many :articles
  #    delegate :as_tags, to: :name
  #  end
  #
  #  class Article < ApplicationRecord
  #    has_and_belongs_to_many :topics
  #    delegate :as_tags, to: :tag_sources
  #
  #    private
  #      def tag_sources
  #        [model_name.singular, topics]
  #      end
  #  end
  #
  #  @article.as_tags # => ["article", "programming", "ruby", "rails"]
  #
  # You may also write the method directly, in which case be sure to respect the method
  # signature and invocation style:
  #
  #  class WarningStyle
  #    def as_tags(tags = [])
  #      %w(red bold).as_tags(tags)
  #    end
  #  end
  #
  #  tag.p "Warning", class: [:alert, WarningStyle.new] # => '<p class="alert red bold">Warning</p>'
  #
  # The result of passing or instantiating an accumulator other than an +Array+,
  # returning any object other than the accumulator array, or self-referential invocation,
  # is undefined.
  #
  def as_tags(tags = [])
    to_s.as_tags(tags)
  end
end

class String
  # Append +self+ to tags accumulator unless blank.
  def as_tags(tags = [])
    present? ? tags << self : tags
  end
end

class FalseClass
  # Returns the +tags+ accumulator unmodified.
  def as_tags(tags = [])
    tags
  end
end

class NilClass
  # Returns the +tags+ accumulator unmodified.
  def as_tags(tags = [])
    tags
  end
end

class Hash
  # Returns the +tags+ accumulator with tags appended for every key with a truthy value.
  def as_tags(tags = [])
    each_pair do |key, value|
      key.as_tags(tags) if value
    end
    tags
  end
end

module Enumerable
  # Accumulate the result of calling +as_tags+ over each element.
  def as_tags(tags = [])
    each_with_object(tags, &:as_tags)
  end
end
