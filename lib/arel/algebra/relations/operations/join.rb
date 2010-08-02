module Arel
  class Join
    include Relation

    attr_reader :relation1, :relation2, :predicates

    def initialize(relation1, relation2 = Nil.instance, *predicates)
      @relation1  = relation1
      @relation2  = relation2
      @predicates = predicates
      @attributes = nil
    end

    def name
      relation1.name
    end

    def attributes
      @attributes ||= (relation1.externalize.attributes | relation2.externalize.attributes).bind(self)
    end

    def wheres
      # TESTME bind to self?
      relation1.externalize.wheres
    end

    def ons
      @ons ||= @predicates.collect { |p| p.bind(self) }
    end

    # TESTME
    def externalizable?
      relation1.externalizable? or relation2.externalizable?
    end

    def join?
      true
    end

    def engine
      relation1.engine != relation2.engine ? Memory::Engine.new : relation1.engine
    end

    def table_sql(formatter = Sql::TableReference.new(self))
      relation1.externalize.table_sql(formatter)
    end

    def joins(environment, formatter = Sql::TableReference.new(environment))
      @joins ||= begin
        this_join = [
          join_sql,
          relation2.externalize.table_sql(formatter),
          ("ON" unless predicates.blank?),
          (ons + relation2.externalize.wheres).collect { |p| p.bind(environment.relation).to_sql(Sql::WhereClause.new(environment)) }.join(' AND ')
        ].compact.join(" ")
        [relation1.joins(environment), this_join, relation2.joins(environment)].compact.join(" ")
      end
    end

    def eval
      result = []
      relation1.call.each do |row1|
        relation2.call.each do |row2|
          combined_row = row1.combine(row2, self)
          if predicates.all? { |p| p.eval(combined_row) }
            result << combined_row
          end
        end
      end
      result
    end

    def to_sql(formatter = nil)
      compiler.select_sql
    end
  end

  class InnerJoin < Join
    def join_sql; "INNER JOIN" end
  end

  class OuterJoin < Join
    def join_sql; "LEFT OUTER JOIN" end
  end

  class StringJoin < Join
    def joins(environment, formatter = Sql::TableReference.new(environment))
       [relation1.joins(environment), relation2].compact.join(" ")
    end

    def externalizable?
      relation1.externalizable?
    end

    def attributes
      relation1.externalize.attributes
    end

    def engine
      relation1.engine
    end
  end
end
