# Ruby 1.9 introduces BasicObject. Use Builder's BlankSlate until then.
unless defined? BasicObject
  require 'blankslate'
  BasicObject = BlankSlate
end
