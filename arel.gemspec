# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{arel}
  s.version = "1.0.1.beta.1.20100924164427"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Aaron Patterson", "Bryan Halmkamp", "Emilio Tagua", "Nick Kallen"]
  s.date = %q{2010-09-24}
  s.description = %q{Arel is a Relational Algebra for Ruby. It 1) simplifies the generation complex of SQL queries and it 2) adapts to various RDBMS systems. It is intended to be a framework framework; that is, you can build your own ORM with it, focusing on innovative object and collection modeling as opposed to database compatibility and query generation.}
  s.email = ["aaron@tenderlovemaking.com", "bryan@brynary.com", "miloops@gmail.com", "nick@example.org"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.markdown"]
  s.files = ["History.txt", "Manifest.txt", "README.markdown", "Rakefile", "arel.gemspec", "lib/arel.rb", "lib/arel/attributes.rb", "lib/arel/attributes/attribute.rb", "lib/arel/compatibility/wheres.rb", "lib/arel/crud.rb", "lib/arel/delete_manager.rb", "lib/arel/deprecated.rb", "lib/arel/expression.rb", "lib/arel/expressions.rb", "lib/arel/insert_manager.rb", "lib/arel/nodes.rb", "lib/arel/nodes/and.rb", "lib/arel/nodes/assignment.rb", "lib/arel/nodes/avg.rb", "lib/arel/nodes/between.rb", "lib/arel/nodes/binary.rb", "lib/arel/nodes/count.rb", "lib/arel/nodes/delete_statement.rb", "lib/arel/nodes/equality.rb", "lib/arel/nodes/exists.rb", "lib/arel/nodes/function.rb", "lib/arel/nodes/greater_than.rb", "lib/arel/nodes/greater_than_or_equal.rb", "lib/arel/nodes/group.rb", "lib/arel/nodes/grouping.rb", "lib/arel/nodes/having.rb", "lib/arel/nodes/in.rb", "lib/arel/nodes/inner_join.rb", "lib/arel/nodes/insert_statement.rb", "lib/arel/nodes/join.rb", "lib/arel/nodes/less_than.rb", "lib/arel/nodes/less_than_or_equal.rb", "lib/arel/nodes/lock.rb", "lib/arel/nodes/max.rb", "lib/arel/nodes/min.rb", "lib/arel/nodes/node.rb", "lib/arel/nodes/not_equal.rb", "lib/arel/nodes/offset.rb", "lib/arel/nodes/on.rb", "lib/arel/nodes/or.rb", "lib/arel/nodes/outer_join.rb", "lib/arel/nodes/select_core.rb", "lib/arel/nodes/select_statement.rb", "lib/arel/nodes/sql_literal.rb", "lib/arel/nodes/string_join.rb", "lib/arel/nodes/sum.rb", "lib/arel/nodes/table_alias.rb", "lib/arel/nodes/unqualified_column.rb", "lib/arel/nodes/update_statement.rb", "lib/arel/nodes/values.rb", "lib/arel/relation.rb", "lib/arel/select_manager.rb", "lib/arel/sql/engine.rb", "lib/arel/sql_literal.rb", "lib/arel/table.rb", "lib/arel/tree_manager.rb", "lib/arel/update_manager.rb", "lib/arel/version.rb", "lib/arel/visitors.rb", "lib/arel/visitors/dot.rb", "lib/arel/visitors/join_sql.rb", "lib/arel/visitors/mysql.rb", "lib/arel/visitors/oracle.rb", "lib/arel/visitors/order_clauses.rb", "lib/arel/visitors/postgresql.rb", "lib/arel/visitors/to_sql.rb", "spec/activerecord_compat_spec.rb", "spec/attributes/attribute_spec.rb", "spec/attributes_spec.rb", "spec/crud_spec.rb", "spec/delete_manager_spec.rb", "spec/insert_manager_spec.rb", "spec/nodes/count_spec.rb", "spec/nodes/delete_statement_spec.rb", "spec/nodes/equality_spec.rb", "spec/nodes/insert_statement_spec.rb", "spec/nodes/or_spec.rb", "spec/nodes/select_core_spec.rb", "spec/nodes/select_statement_spec.rb", "spec/nodes/sql_literal_spec.rb", "spec/nodes/sum_spec.rb", "spec/nodes/update_statement_spec.rb", "spec/select_manager_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "spec/support/check.rb", "spec/support/fake_record.rb", "spec/support/matchers.rb", "spec/support/matchers/be_like.rb", "spec/support/shared/tree_manager_shared.rb", "spec/table_spec.rb", "spec/update_manager_spec.rb", "spec/visitors/join_sql_spec.rb", "spec/visitors/oracle_spec.rb", "spec/visitors/to_sql_spec.rb"]
  s.homepage = %q{http://github.com/rails/arel}
  s.rdoc_options = ["--main", "README.markdown"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{arel}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Arel is a Relational Algebra for Ruby}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, [">= 2.6.0"])
    else
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, [">= 2.6.0"])
    end
  else
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, [">= 2.6.0"])
  end
end
