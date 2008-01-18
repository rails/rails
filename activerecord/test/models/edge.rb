# This class models an edge in a directed graph.
class Edge < ActiveRecord::Base
  belongs_to :source, :class_name => 'Vertex', :foreign_key => 'source_id'
  belongs_to :sink,   :class_name => 'Vertex', :foreign_key => 'sink_id'
end
