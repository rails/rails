# frozen_string_literal: true

exception = Exception.new("I am not blamable!")
class << exception
  undef_method(:blame_file!)
end
raise exception
