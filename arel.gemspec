# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{arel}
  s.version = "2.2.0.20110809140134"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Aaron Patterson}, %q{Bryan Halmkamp}, %q{Emilio Tagua}, %q{Nick Kallen}]
  s.date = %q{2011-08-09}
  s.description = %q{Arel is a SQL AST manager for Ruby. It

1. Simplifies the generation complex of SQL queries
2. Adapts to various RDBMS systems

It is intended to be a framework framework; that is, you can build your own ORM
with it, focusing on innovative object and collection modeling as opposed to
database compatibility and query generation.}
  s.email = [%q{aaron@tenderlovemaking.com}, %q{bryan@brynary.com}, %q{miloops@gmail.com}, %q{nick@example.org}]
  s.extra_rdoc_files = [%q{History.txt}, %q{MIT-LICENSE.txt}, %q{Manifest.txt}, %q{README.markdown}]
  s.files = [%q{.autotest}, %q{.gemtest}, %q{Gemfile}, %q{History.txt}, %q{MIT-LICENSE.txt}, %q{Manifest.txt}, %q{README.markdown}, %q{Rakefile}, %q{arel.gemspec}, %q{lib/arel.rb}, %q{lib/arel/alias_predication.rb}, %q{lib/arel/attributes.rb}, %q{lib/arel/attributes/attribute.rb}, %q{lib/arel/compatibility/wheres.rb}, %q{lib/arel/crud.rb}, %q{lib/arel/delete_manager.rb}, %q{lib/arel/deprecated.rb}, %q{lib/arel/expression.rb}, %q{lib/arel/expressions.rb}, %q{lib/arel/factory_methods.rb}, %q{lib/arel/insert_manager.rb}, %q{lib/arel/math.rb}, %q{lib/arel/nodes.rb}, %q{lib/arel/nodes/and.rb}, %q{lib/arel/nodes/ascending.rb}, %q{lib/arel/nodes/binary.rb}, %q{lib/arel/nodes/count.rb}, %q{lib/arel/nodes/delete_statement.rb}, %q{lib/arel/nodes/descending.rb}, %q{lib/arel/nodes/equality.rb}, %q{lib/arel/nodes/false.rb}, %q{lib/arel/nodes/function.rb}, %q{lib/arel/nodes/in.rb}, %q{lib/arel/nodes/infix_operation.rb}, %q{lib/arel/nodes/inner_join.rb}, %q{lib/arel/nodes/insert_statement.rb}, %q{lib/arel/nodes/join_source.rb}, %q{lib/arel/nodes/named_function.rb}, %q{lib/arel/nodes/node.rb}, %q{lib/arel/nodes/ordering.rb}, %q{lib/arel/nodes/outer_join.rb}, %q{lib/arel/nodes/select_core.rb}, %q{lib/arel/nodes/select_statement.rb}, %q{lib/arel/nodes/sql_literal.rb}, %q{lib/arel/nodes/string_join.rb}, %q{lib/arel/nodes/table_alias.rb}, %q{lib/arel/nodes/terminal.rb}, %q{lib/arel/nodes/true.rb}, %q{lib/arel/nodes/unary.rb}, %q{lib/arel/nodes/unqualified_column.rb}, %q{lib/arel/nodes/update_statement.rb}, %q{lib/arel/nodes/values.rb}, %q{lib/arel/nodes/with.rb}, %q{lib/arel/order_predications.rb}, %q{lib/arel/predications.rb}, %q{lib/arel/relation.rb}, %q{lib/arel/select_manager.rb}, %q{lib/arel/sql/engine.rb}, %q{lib/arel/sql_literal.rb}, %q{lib/arel/table.rb}, %q{lib/arel/tree_manager.rb}, %q{lib/arel/update_manager.rb}, %q{lib/arel/visitors.rb}, %q{lib/arel/visitors/depth_first.rb}, %q{lib/arel/visitors/dot.rb}, %q{lib/arel/visitors/ibm_db.rb}, %q{lib/arel/visitors/informix.rb}, %q{lib/arel/visitors/join_sql.rb}, %q{lib/arel/visitors/mssql.rb}, %q{lib/arel/visitors/mysql.rb}, %q{lib/arel/visitors/oracle.rb}, %q{lib/arel/visitors/order_clauses.rb}, %q{lib/arel/visitors/postgresql.rb}, %q{lib/arel/visitors/sqlite.rb}, %q{lib/arel/visitors/to_sql.rb}, %q{lib/arel/visitors/visitor.rb}, %q{lib/arel/visitors/where_sql.rb}, %q{test/attributes/test_attribute.rb}, %q{test/helper.rb}, %q{test/nodes/test_as.rb}, %q{test/nodes/test_ascending.rb}, %q{test/nodes/test_bin.rb}, %q{test/nodes/test_count.rb}, %q{test/nodes/test_delete_statement.rb}, %q{test/nodes/test_descending.rb}, %q{test/nodes/test_equality.rb}, %q{test/nodes/test_infix_operation.rb}, %q{test/nodes/test_insert_statement.rb}, %q{test/nodes/test_named_function.rb}, %q{test/nodes/test_node.rb}, %q{test/nodes/test_not.rb}, %q{test/nodes/test_or.rb}, %q{test/nodes/test_select_core.rb}, %q{test/nodes/test_select_statement.rb}, %q{test/nodes/test_sql_literal.rb}, %q{test/nodes/test_sum.rb}, %q{test/nodes/test_update_statement.rb}, %q{test/support/fake_record.rb}, %q{test/test_activerecord_compat.rb}, %q{test/test_attributes.rb}, %q{test/test_crud.rb}, %q{test/test_delete_manager.rb}, %q{test/test_factory_methods.rb}, %q{test/test_insert_manager.rb}, %q{test/test_select_manager.rb}, %q{test/test_table.rb}, %q{test/test_update_manager.rb}, %q{test/visitors/test_depth_first.rb}, %q{test/visitors/test_dot.rb}, %q{test/visitors/test_ibm_db.rb}, %q{test/visitors/test_informix.rb}, %q{test/visitors/test_join_sql.rb}, %q{test/visitors/test_mssql.rb}, %q{test/visitors/test_mysql.rb}, %q{test/visitors/test_oracle.rb}, %q{test/visitors/test_postgres.rb}, %q{test/visitors/test_sqlite.rb}, %q{test/visitors/test_to_sql.rb}]
  s.homepage = %q{http://github.com/rails/arel}
  s.rdoc_options = [%q{--main}, %q{README.markdown}]
  s.require_paths = [%q{lib}]
  s.rubyforge_project = %q{arel}
  s.rubygems_version = %q{1.8.6.1}
  s.summary = %q{Arel is a SQL AST manager for Ruby}
  s.test_files = [%q{test/attributes/test_attribute.rb}, %q{test/nodes/test_as.rb}, %q{test/nodes/test_ascending.rb}, %q{test/nodes/test_bin.rb}, %q{test/nodes/test_count.rb}, %q{test/nodes/test_delete_statement.rb}, %q{test/nodes/test_descending.rb}, %q{test/nodes/test_equality.rb}, %q{test/nodes/test_infix_operation.rb}, %q{test/nodes/test_insert_statement.rb}, %q{test/nodes/test_named_function.rb}, %q{test/nodes/test_node.rb}, %q{test/nodes/test_not.rb}, %q{test/nodes/test_or.rb}, %q{test/nodes/test_select_core.rb}, %q{test/nodes/test_select_statement.rb}, %q{test/nodes/test_sql_literal.rb}, %q{test/nodes/test_sum.rb}, %q{test/nodes/test_update_statement.rb}, %q{test/test_activerecord_compat.rb}, %q{test/test_attributes.rb}, %q{test/test_crud.rb}, %q{test/test_delete_manager.rb}, %q{test/test_factory_methods.rb}, %q{test/test_insert_manager.rb}, %q{test/test_select_manager.rb}, %q{test/test_table.rb}, %q{test/test_update_manager.rb}, %q{test/visitors/test_depth_first.rb}, %q{test/visitors/test_dot.rb}, %q{test/visitors/test_ibm_db.rb}, %q{test/visitors/test_informix.rb}, %q{test/visitors/test_join_sql.rb}, %q{test/visitors/test_mssql.rb}, %q{test/visitors/test_mysql.rb}, %q{test/visitors/test_oracle.rb}, %q{test/visitors/test_postgres.rb}, %q{test/visitors/test_sqlite.rb}, %q{test/visitors/test_to_sql.rb}]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, ["~> 2.10"])
    else
      s.add_dependency(%q<hoe>, ["~> 2.10"])
    end
  else
    s.add_dependency(%q<hoe>, ["~> 2.10"])
  end
end
