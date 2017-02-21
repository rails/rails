# # -*- encoding: utf-8 -*-
# frozen_string_literal: true
$:.push File.expand_path("../lib", __FILE__)
require "arel"

Gem::Specification.new do |s|
  s.name        = "arel"
  s.version     = Arel::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Aaron Patterson", "Bryan Helmkamp", "Emilio Tagua", "Nick Kallen"]
  s.email       = ["aaron@tenderlovemaking.com", "bryan@brynary.com", "miloops@gmail.com"]
  s.homepage    = "https://github.com/rails/arel"
  s.description = "Arel Really Exasperates Logicians\n\nArel is a SQL AST manager for Ruby. It\n\n1. Simplifies the generation of complex SQL queries\n2. Adapts to various RDBMSes\n\nIt is intended to be a framework framework; that is, you can build your own ORM\nwith it, focusing on innovative object and collection modeling as opposed to\ndatabase compatibility and query generation."
  s.summary     = "Arel Really Exasperates Logicians  Arel is a SQL AST manager for Ruby"
  s.license     = %q{MIT}

  s.rdoc_options = ["--main", "README.md"]
  s.extra_rdoc_files = ["History.txt", "MIT-LICENSE.txt", "README.md"]

  s.files         = ["History.txt","MIT-LICENSE.txt","README.md","lib/arel.rb","lib/arel/alias_predication.rb","lib/arel/attributes.rb","lib/arel/attributes/attribute.rb","lib/arel/collectors/bind.rb","lib/arel/collectors/plain_string.rb","lib/arel/collectors/sql_string.rb","lib/arel/compatibility/wheres.rb","lib/arel/crud.rb","lib/arel/delete_manager.rb","lib/arel/errors.rb","lib/arel/expressions.rb","lib/arel/factory_methods.rb","lib/arel/insert_manager.rb","lib/arel/math.rb","lib/arel/nodes.rb","lib/arel/nodes/and.rb","lib/arel/nodes/ascending.rb","lib/arel/nodes/binary.rb","lib/arel/nodes/bind_param.rb","lib/arel/nodes/case.rb","lib/arel/nodes/casted.rb","lib/arel/nodes/count.rb","lib/arel/nodes/delete_statement.rb","lib/arel/nodes/descending.rb","lib/arel/nodes/equality.rb","lib/arel/nodes/extract.rb","lib/arel/nodes/false.rb","lib/arel/nodes/full_outer_join.rb","lib/arel/nodes/function.rb","lib/arel/nodes/grouping.rb","lib/arel/nodes/in.rb","lib/arel/nodes/infix_operation.rb","lib/arel/nodes/inner_join.rb","lib/arel/nodes/insert_statement.rb","lib/arel/nodes/join_source.rb","lib/arel/nodes/matches.rb","lib/arel/nodes/named_function.rb","lib/arel/nodes/node.rb","lib/arel/nodes/outer_join.rb","lib/arel/nodes/over.rb","lib/arel/nodes/regexp.rb","lib/arel/nodes/right_outer_join.rb","lib/arel/nodes/select_core.rb","lib/arel/nodes/select_statement.rb","lib/arel/nodes/sql_literal.rb","lib/arel/nodes/string_join.rb","lib/arel/nodes/table_alias.rb","lib/arel/nodes/terminal.rb","lib/arel/nodes/true.rb","lib/arel/nodes/unary.rb","lib/arel/nodes/unary_operation.rb","lib/arel/nodes/unqualified_column.rb","lib/arel/nodes/update_statement.rb","lib/arel/nodes/values.rb","lib/arel/nodes/window.rb","lib/arel/nodes/with.rb","lib/arel/order_predications.rb","lib/arel/predications.rb","lib/arel/select_manager.rb","lib/arel/table.rb","lib/arel/tree_manager.rb","lib/arel/update_manager.rb","lib/arel/visitors.rb","lib/arel/visitors/bind_substitute.rb","lib/arel/visitors/bind_visitor.rb","lib/arel/visitors/depth_first.rb","lib/arel/visitors/dot.rb","lib/arel/visitors/ibm_db.rb","lib/arel/visitors/informix.rb","lib/arel/visitors/mssql.rb","lib/arel/visitors/mysql.rb","lib/arel/visitors/oracle.rb","lib/arel/visitors/oracle12.rb","lib/arel/visitors/postgresql.rb","lib/arel/visitors/reduce.rb","lib/arel/visitors/sqlite.rb","lib/arel/visitors/to_sql.rb","lib/arel/visitors/visitor.rb","lib/arel/visitors/where_sql.rb","lib/arel/window_predications.rb"]
  s.require_paths = ["lib"]

  s.add_development_dependency('minitest', '~> 5.4')
  s.add_development_dependency('rdoc', '~> 4.0')
  s.add_development_dependency('rake')
end
