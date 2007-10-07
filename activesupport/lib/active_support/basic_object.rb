# Ruby 1.9 introduces BasicObject. Use Builder's BlankSlate until then.
unless defined? BasicObject
  require 'builder/blankslate'
  BasicObject = Builder::BlankSlate
end
