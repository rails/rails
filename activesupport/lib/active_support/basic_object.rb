# Ruby 1.9 introduces BasicObject. Use Builder's BlankSlate before then.
unless defined? BasicObject
  require 'rubygems'
  require 'builder'
  BasicObject = Builder::BlankSlate
end
