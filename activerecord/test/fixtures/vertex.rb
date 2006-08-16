# This class models a vertex in a directed graph.
class Vertex < ActiveRecord::Base
  has_many :sink_edges, :class_name => 'Edge', :foreign_key => 'source_id'
  has_many :sinks, :through => :sink_edges, :source => :sink

  has_and_belongs_to_many :sources,
    :class_name => 'Vertex', :join_table => 'edges',
    :foreign_key => 'sink_id', :association_foreign_key => 'source_id'
end
