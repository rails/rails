require 'rubygems'
require 'active_resource'
require 'benchmark'

TIMES = (ENV['N'] || 10_000).to_i

# deep nested resource
attrs = {
  :id => 1,
  :name => 'Luis',
  :age => 21,
  :friends => [
    {
      :name => 'JK',
      :age => 24,
      :colors => ['red', 'green', 'blue'],
      :brothers => [
        {
          :name => 'Mateo',
          :age => 35,
          :children => [{ :name => 'Edith', :age => 5 }, { :name => 'Martha', :age => 4 }]
        },
        {
          :name => 'Felipe',
          :age => 33,
          :children => [{ :name => 'Bryan', :age => 1 }, { :name => 'Luke', :age => 0 }]
        }
      ]
    },
    {
      :name => 'Eduardo',
      :age => 20,
      :colors => [],
      :brothers => [
        {
          :name => 'Sebas',
          :age => 23,
          :children => [{ :name => 'Andres', :age => 0 }, { :name => 'Jorge', :age => 2 }]
        },
        {
          :name => 'Elsa',
          :age => 19,
          :children => [{ :name => 'Natacha', :age => 1 }]
        },
        {
          :name => 'Milena',
          :age => 16,
          :children => []
        }
      ]
    }
  ]
}

class Customer < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
end

module Nested
  class Customer < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000"
  end
end

Benchmark.bm(40) do |x|
  x.report('Model.new (instantiation)')              { TIMES.times { Customer.new } }
  x.report('Nested::Model.new (instantiation)')      { TIMES.times { Nested::Customer.new } }
  x.report('Model.new (setting attributes)')         { TIMES.times { Customer.new attrs } }
  x.report('Nested::Model.new (setting attributes)') { TIMES.times { Nested::Customer.new attrs } }
end
