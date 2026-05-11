---
name: rails-minitest-spec-to-test
description: 'Rewrite Rails tests from Minitest::Spec syntax to classic Minitest test syntax without changing behavior. Use when converting describe/it/before blocks into Active Support test "..." blocks or def test_* methods, plus setup and helpers, while preserving assertions, helper calls, and setup scope.'
argument-hint: 'Target Rails test file or files to convert'
---

# Rails Minitest Spec To Test Conversion

Use this skill when converting Rails test files from Minitest::Spec style to classic Minitest test syntax.

It is especially useful for files that currently mix classic tests with `describe` and `it` blocks, such as the Arel tests under `activerecord/test/cases/arel/`.

The goal is structural translation only:
- Preserve the same assertions, expectations, helper calls, SQL strings, and setup intent.
- Keep module, class, and require structure unchanged.
- Do not change semantics just to make the file look more idiomatic.
- When the spec helper defines a classic test base with equivalent setup and teardown, switch the test class to that base as part of the conversion.

## Procedure

1. Identify the owning test class and the exact spec constructs in use.
Look for `describe`, `it`, and hook blocks such as `before` inside the existing test class.

2. Keep the outer file structure intact.
Preserve `# frozen_string_literal: true`, `require_relative` lines, any enclosing modules, and the existing test class declaration.

3. Resolve the effective base class, not just the literal superclass on the file.
Check helper files and nearby support code for paired test bases such as a spec-style class and a classic test-style class with matching setup and teardown.
If the converted file should inherit from an `ActiveSupport::TestCase`-based class, switch the class to that base and use `test "..." do` blocks.
If the surrounding test support only provides method-style tests, keep or switch to the appropriate method-style base and use `def test_...` methods.

4. Convert each example to the chosen test form.
For `ActiveSupport::TestCase`, keep the example text readable as the `test` name.
When an `it` block is already top-level, preserve its text directly unless a collision forces a small disambiguation.
When an `it` block was nested under one or more `describe` blocks, fold only the needed context into the `test` string.
For method-style tests, build the method name from the nested context path plus the example text.

5. Update the test superclass when the support layer expects it.
For example, if a file currently inherits from a spec-only base like `Arel::Spec` but the helper defines `Arel::Test < ActiveSupport::TestCase` with equivalent environment setup, convert the file to inherit from `Arel::Test`.

6. Flatten `describe` blocks that only group examples.
If a `describe` block exists only to namespace example names, remove the block and encode that context into the test method names.

7. Translate setup hooks without widening their scope.
If a `before` block applies to every remaining test in the class, convert it to `setup`.
If a `before` block only applies to one nested context, prefer a helper method or explicit setup statements at the start of each affected test instead of moving that state into class-wide `setup`.

8. Rewrite spec expectation helpers into classic assertions when converting to `ActiveSupport::TestCase`.
Do not keep `_()` expectation calls in converted classic tests.
Prefer `assert_equal`, `assert_kind_of`, `assert_match`, `assert_includes`, `assert_nil`, `assert_not`, and project-specific helpers such as `assert_like`.
Keep spec expectation syntax only in files that remain spec-style.

9. Keep execution order and grouping intent readable.
Retain the original example order. When a nested context materially clarifies behavior, reflect it in the generated method names instead of inventing comments or rearranging tests.

10. Run the narrowest relevant test command after editing.
From the owning component directory, prefer `bin/test` with the touched file path.
For Arel files, from `activerecord/`, use `bin/test test/cases/arel/<file>_test.rb`.

## Naming Rules

- For `ActiveSupport::TestCase`, keep the `test` string descriptive and close to the original `it` text.
- For top-level `it` blocks in `ActiveSupport::TestCase`, usually keep the original example text unchanged.
- For nested `describe` contexts in `ActiveSupport::TestCase`, prepend only the needed context to keep the `test` string clear and unique.
- If a `describe` label starts with `#` or `.`, keep that method marker in the resulting `test` string.
- For method-style tests, join nested `describe` labels and the `it` text into one snake_case test name.
- Remove punctuation that is not useful in a Ruby method name.
- Prefer descriptive names over short ones.
- Keep names or method names stable and unique within the class.
- If you switch to an `ActiveSupport::TestCase`-based superclass, prefer preserving readable example text over mechanically generating `def test_...` names.

## Assertion Rewrite Rules

- Rewrite `_(actual).must_equal expected` to `assert_equal expected, actual`.
- Rewrite `_(actual).wont_equal expected` to `assert_not_equal expected, actual`.
- Rewrite `_(actual).must_be_kind_of(Type)` to `assert_kind_of Type, actual`.
- Rewrite `_(actual).must_match(pattern)` to `assert_match pattern, actual`.
- Rewrite SQL whitespace-insensitive comparisons such as `_(sql).must_be_like expected_sql` to `assert_like expected_sql, sql`.
- Do not introduce or retain an `_` helper on `ActiveSupport::TestCase` just to avoid rewriting expectations.

Examples:

- Top-level `it "responds to lower"` in an `ActiveSupport::TestCase` file -> `test "responds to lower" do`
- `describe "#hash"` + `it "is equal when eql? returns true"` in an `ActiveSupport::TestCase` file -> `test "#hash is equal when eql? returns true" do`
- `describe "validation"` + `it "rejects blank names"` in an `ActiveSupport::TestCase` -> `test "validation rejects blank names" do`
- `class CrudTest < Arel::Spec` with `Arel::Test < ActiveSupport::TestCase` available -> `class CrudTest < Arel::Test`
- `describe "backwards compatibility"` + `describe "project"` + `it "accepts symbols as sql literals"` -> `def test_backwards_compatibility_project_accepts_symbols_as_sql_literals`
- `_(manager.to_sql).must_be_like %{ INSERT INTO "users" }` in a converted classic test -> `assert_like %{ INSERT INTO "users" }, manager.to_sql`

## Decision Points

### Converting `before`

- Use `setup` only when the hook truly applies to all tests that will remain in the class.
- Use a private helper when the hook belongs to one former nested context.
- Inline setup statements into a test when that is the smallest faithful translation.

### Choosing `test` vs `def test_`

- Use `test "..." do` for classes inheriting from `ActiveSupport::TestCase` or from a project-specific base class built on `ActiveSupport::TestCase`.
- Use `def test_...` only when the surrounding test base and local file style call for method-style tests.
- Do not rewrite an `ActiveSupport::TestCase` file into method-style tests just because the names can be mechanically generated.

### Choosing the superclass

- Do not assume the current spec superclass remains correct after conversion.
- If the support layer provides a classic test superclass with equivalent fixture or engine setup, switch to that superclass.
- In Arel tests, `Arel::Spec` is the spec DSL base and `Arel::Test` is the classic `ActiveSupport::TestCase` base.

### Handling nested `describe`

- Remove the nesting when it only provides namespacing.
- Preserve the context in the generated test method names.
- For `test "..." do` syntax, add only the minimum context needed for readability or uniqueness.
- Preserve leading `#` and `.` markers from method-oriented `describe` labels.
- If multiple examples would otherwise collide, add the smallest extra context needed to keep method names unique.

## Completion Checks

- The converted file has the same number of runnable examples as before.
- No `describe`, `it`, or `before` blocks remain in the converted class unless intentionally left for a reason you can justify.
- Shared state was not broadened from a nested context to the whole class by accident.
- Assertions and expectation calls are unchanged except for mechanical movement into test methods.
- Converted `ActiveSupport::TestCase` files do not use `_()` expectation helpers.
- `ActiveSupport::TestCase` files use `test "..." do` blocks after conversion.
- The converted class inherits from the correct classic test base when the helper defines one.
- The touched file passes its focused test run.

## Worked Patterns

Generic conversion:

```ruby
it "responds to lower" do
  relation  = Table.new(:users)
  attribute = relation[:foo]
  node      = attribute.lower
  assert_equal "LOWER", node.name
end
```

```ruby
test "responds to lower" do
  relation  = Table.new(:users)
  attribute = relation[:foo]
  node      = attribute.lower
  assert_equal "LOWER", node.name
end
```

Nested context conversion:

```ruby
describe "validation" do
  it "rejects blank names" do
    record = Model.new(name: "")
    assert_not record.valid?
  end
end
```

```ruby
test "validation rejects blank names" do
  record = Model.new(name: "")
  assert_not record.valid?
end
```

Arel-specific conversion:

Starting point:

```ruby
class CrudTest < Arel::Spec
  describe "delete" do
    it "should call delete on the connection" do
      table = Table.new :users
      fc = FakeCrudder.new
      fc.from table
      stmt = fc.compile_delete
      assert_instance_of Arel::DeleteManager, stmt
    end
  end
end
```

Converted form:

```ruby
class CrudTest < Arel::Test
  test "delete should call delete on the connection" do
    table = Table.new :users
    fc = FakeCrudder.new
    fc.from table
    stmt = fc.compile_delete
    assert_instance_of Arel::DeleteManager, stmt
  end
end
```

For nested setup:

```ruby
before do
  table = Table.new :users
  @m1 = Arel::SelectManager.new table
  @m1.project Arel.star
end
```

Convert to `setup` only if every remaining test uses `@m1`. Otherwise extract a helper such as `build_union_managers` and call it from the affected tests.
