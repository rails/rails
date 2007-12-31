class JoinRelation < Relation
  attr_reader :relation1, :relation2, :predicates
  
  def initialize(relation1, relation2, *predicates)
    @relation1, @relation2, @predicates = relation1, relation2, predicates
  end
  
  def ==(other)
    predicates == other.predicates and
      ((relation1 == other.relation1 and relation2 == other.relation2) or
      (relation2 == other.relation1 and relation1 == other.relation2))
  end
  
  def to_sql(builder = SelectBuilder.new)
    enclosed_join_name, enclosed_predicates = join_name, predicates
    relation2.to_sql(Adapter.new(relation1.to_sql(builder)) do
      define_method :from do |table|
        send(enclosed_join_name, table) do
          enclosed_predicates.each do |predicate|
            predicate.to_sql(self)
          end
        end
      end
    end)
  end
  
  class Adapter
    instance_methods.each { |m| undef_method m unless m =~ /^__|^instance_eval/ }
      
    def initialize(adaptee, &block)
      @adaptee = adaptee
      (class << self; self end).class_eval do
        (adaptee.methods - instance_methods).each { |m| delegate m, :to => :@adaptee }
      end
      (class << self; self end).class_eval(&block)
    end
    
    def call(&block)
      @caller = eval("self", block.binding)
      returning self do |adapter|
        instance_eval(&block)
      end
    end
    
    def method_missing(method, *args, &block)
      @caller.send(method, *args, &block)
    end
  end
end