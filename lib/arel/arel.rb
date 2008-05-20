def Arel(name, engine = Arel::Table.engine)
  Arel::Table.new(name, engine)
end