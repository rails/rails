# I have access to my directory and the Rails config.
raise 'directory expected but undefined in init.rb' unless defined? directory
raise 'config expected but undefined in init.rb' unless defined? config

# My lib/ dir must be in the load path.
require 'stubby_mixin'
raise 'missing mixin from my lib/ dir' unless defined? StubbyMixin
