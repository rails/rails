# frozen_string_literal: true

# :markup: markdown

module ActiveStorage::Attached::EnumerableCollection # :nodoc:
  include Enumerable

  def find(*args, &block)
    if args.any? && !block
      raise ActiveStorage::QueryNotSupported, "Use find_by(id: id) or find { |record| ... } to search generic attachment collections."
    end

    super
  end

  def find_by(attributes)
    to_a.find { |record| attributes.all? { |key, value| record.public_send(key) == value } }
  end

  def pluck(*columns)
    to_a.map do |record|
      columns.one? ? record.public_send(columns.first) : columns.map { |column| record.public_send(column) }
    end
  end

  def reset
    reload
  end

  def where(*)
    raise ActiveStorage::QueryNotSupported, query_unsupported_message("where")
  end

  def order(*)
    raise ActiveStorage::QueryNotSupported, query_unsupported_message("order")
  end
end
