# -*- coding: utf-8 -*-

module ActiveRecord
  # = Active Record Null Relation
  class NullRelation < Relation
    def exec_queries
      @records = []
    end
  end
end