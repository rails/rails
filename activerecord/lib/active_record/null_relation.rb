# -*- coding: utf-8 -*-

module ActiveRecord
  # = Active Record Null Relation
  class NullRelation < Relation
    def initialize(klass, table)
      super
      @where_values += ["33<3"]
    end

    def exec_queries
      @records = []
    end
  end
end