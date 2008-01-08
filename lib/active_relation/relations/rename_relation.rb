class RenameRelation < CompoundRelation
  attr_reader :relation, :schmattribute, :alias
  
  def initialize(relation, renames)
    @schmattribute, @alias = renames.shift
    @relation = renames.empty?? relation : RenameRelation.new(relation, renames)
  end
  
  def ==(other)
    relation == other.relation and schmattribute.eql?(other.schmattribute) and self.alias == other.alias
  end
  
  def attributes
    relation.attributes.collect { |a| substitute(a) }
  end
  
  def qualify
    RenameRelation.new(relation.qualify, schmattribute.qualify => self.alias)
  end
  
  protected
  def attribute(name)
    case
    when name == self.alias then schmattribute.alias(self.alias)
    when relation[name].eql?(schmattribute) then nil
    else relation[name]
    end
  end
  
  private
  def substitute(a)
    a.eql?(schmattribute) ? a.alias(self.alias) : a
  end
end