# frozen_string_literal: true

class Hash
  # Sorts the hash by value in ascending order. For example,
  #
  #   data = data.sort_by_value
  #
  # is equivalent to
  #
  #   data = data.sort_by {|key, value| value }
  #
  def sort_by_value
    sort_by {|_, value| value }
  end
  alias_method :with_defaults, :sort_by_value

end
