module Enumerable
  def first_match
    match = nil
    each do |items|
      break if match = yield(items)
    end
    match
  end
end