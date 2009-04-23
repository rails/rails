def Arel(name, engine = (Arel::Table.engine || ActiveRecord::Base.connection))
  Arel::Table.new(name, engine)
end
