class RenameRelation < CompoundRelation
  attr_reader :relation, :schmattribute, :aliaz
  
  def initialize(relation, renames)
    @schmattribute, @aliaz = renames.shift
    @relation = renames.empty?? relation : RenameRelation.new(relation, renames)
  end
  
  def ==(other)
    relation == other.relation and schmattribute.eql?(other.schmattribute) and aliaz == other.aliaz
  end
  
  def attributes
    relation.attributes.collect { |a| substitute(a) }
  end
  
  def qualify
    RenameRelation.new(relation.qualify, schmattribute.qualify => aliaz)
  end
  
  protected
  def attribute(name)
    case
    when name == aliaz then schmattribute.aliazz(aliaz)
    when relation[name].eql?(schmattribute) then nil
    else relation[name]
    end
  end
  
  private
  def substitute(a)
    a.eql?(schmattribute) ? a.aliazz(aliaz) : a
  end
end