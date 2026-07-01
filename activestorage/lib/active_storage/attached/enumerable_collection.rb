# frozen_string_literal: true

module ActiveStorage::Attached::EnumerableCollection # :nodoc:
  include Enumerable

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

  def any?(&block)
    if block_given?
      to_a.any?(&block)
    else
      !empty?
    end
  end

  def where(*)
    raise ActiveStorage::QueryNotSupported, query_unsupported_message("where")
  end

  def order(*)
    raise ActiveStorage::QueryNotSupported, query_unsupported_message("order")
  end
end
