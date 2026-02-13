# Rails Codebase Guide for AI Coding Agents

## Architecture Overview

Rails is a **monorepo containing 10+ independent frameworks** that can work standalone or together. Each framework lives in its own directory at the root level:

- **Active Record** (`activerecord/`) - ORM and database abstraction
- **Action Pack** (`actionpack/`) - Controllers and routing (contains Action Controller and Action Dispatch)
- **Action View** (`actionview/`) - View templates and helpers (extracted from Action Pack in Rails 3)
- **Active Model** (`activemodel/`) - Model interfaces without database dependency
- **Active Support** (`activesupport/`) - Core extensions and utilities used across all frameworks
- **Action Mailer** (`actionmailer/`), **Action Mailbox** (`actionmailbox/`) - Email sending/receiving
- **Active Job** (`activejob/`) - Background job abstraction
- **Action Cable** (`actioncable/`) - WebSocket integration
- **Active Storage** (`activestorage/`) - File uploads and cloud storage
- **Action Text** (`actiontext/`) - Rich text content
- **Railties** (`railties/`) - Rails CLI, generators, and framework glue

**Key architectural principle**: Frameworks are loosely coupled. Changes to one framework should not break others unless there's an explicit dependency.

## Testing Commands

### Running Tests in a Framework
```bash
# From framework directory (preferred method)
cd actionview && bin/test                    # Run all tests
cd actionview && bin/test test/template/form_helper_test.rb
cd actionview && bin/test -n "/test_name/"   # Filter by test name pattern

# Run specific test method
cd actionview && bin/test test/template/form_helper_test.rb::FormHelperTest#test_hidden_field
```

### Running Tests from Root
```bash
# Run all tests for a framework
rake actionview:test

# Run tests across all frameworks
rake test              # Run all non-isolated tests
rake test:isolated     # Run isolated tests
rake smoke            # Quick smoke test
```

### Active Record Testing (Multiple Database Adapters)
```bash
cd activerecord
bundle exec rake test:sqlite3        # Default SQLite
bundle exec rake test:postgresql
bundle exec rake test:mysql2
bundle exec rake test:trilogy
```

**Important**: Tests run in parallel using multiple processes. The `bin/test` script wraps Rails' custom test runner (`tools/test.rb`) which uses `Rails::TestUnit::Runner`.

## Configuration Testing Patterns

When testing configuration options, use `Object#with` (from Active Support) to temporarily modify class attributes:

```ruby
# Correct: Use Object#with for temporary config changes
ActionView::Base.with(remove_hidden_field_autocomplete: true) do
  # Test code here
end

# Avoid: Manual set/restore patterns
old = ActionView::Base.remove_hidden_field_autocomplete
ActionView::Base.remove_hidden_field_autocomplete = true
# ... test code
ActionView::Base.remove_hidden_field_autocomplete = old
```

This pattern is used throughout the test suite, especially for:
- `ActionView::Base.with(config_option: value)`
- `ActionController::Base.with(config_option: value)`
- Other framework configuration testing

**Requires**: `require "active_support/core_ext/object/with"` at the top of test files.

## Code Conventions

### Configuration Flags
Configuration options follow a consistent pattern across frameworks:

1. **Define the attribute** in the base class (e.g., `ActionView::Base`):
   ```ruby
   cattr_accessor :remove_hidden_field_autocomplete, default: false
   ```

2. **Check the flag** before applying behavior:
   ```ruby
   @options.reverse_merge!(autocomplete: "off") unless ActionView::Base.remove_hidden_field_autocomplete
   ```

3. **Enable by default** in new Rails versions via `load_defaults`:
   ```ruby
   # In railties/lib/rails/application/configuration.rb
   case target_version.to_s
   when "8.1"
     action_view.remove_hidden_field_autocomplete = true
   end
   ```

### Changelog Updates
When fixing bugs or adding features:
- Add entry to the top of `<framework>/CHANGELOG.md`
- Format: Brief description, then `*Your Name*` on new line
- See existing entries for style

### Test Naming
- Use descriptive names: `test_hidden_field_omits_autocomplete_when_remove_hidden_field_autocomplete_is_true`
- Group related tests together in the file
- Test both default behavior AND explicit overrides

### Code Style
- Run RuboCop: `bundle exec rubocop` (from framework directory)
- Prefer `assert_not` over `assert !` (Rails/AssertNot cop)
- Prefer `assert_dom_equal` for HTML comparisons in view tests
- Use `# frozen_string_literal: true` at top of all files

## Common Development Workflows

### Making a Fix Across Multiple Components
Example: Issue #55984 required changes to:
1. Helper class: `actionview/lib/action_view/helpers/tags/hidden_field.rb`
2. Tests: `actionview/test/template/form_helper_test.rb`
3. Reference: Similar fixes were in `tags/check_box.rb`, `tags/file_field.rb`, `form_tag_helper.rb`, `url_helper.rb`

**Pattern**: When fixing a configuration flag, grep for similar patterns in other helpers:
```bash
grep -r "unless ActionView::Base.remove_hidden_field_autocomplete" actionview/lib/
```

### Finding Related Code
- **Similar functionality**: Look in the same `lib/*/helpers/` or `lib/*/tags/` directory
- **Tests for a helper**: Check `test/template/<helper_name>_test.rb`
- **Configuration setup**: Check `railties/lib/rails/application/configuration.rb`
- **Default values**: Look for `load_defaults` version blocks

### Working with Forms and Helpers
Action View helpers follow this structure:
- **Tag helpers** (`lib/action_view/helpers/tags/`) - Individual form elements
- **Form helpers** (`lib/action_view/helpers/form_helper.rb`) - Form builders
- **Form tag helpers** (`lib/action_view/helpers/form_tag_helper.rb`) - Standalone tags

When modifying form behavior, check ALL three locations for consistency.

## Issue References and Pull Requests

- Always reference issue numbers in commits: `Fix #12345: Description`
- Check for previous related PRs/issues when fixing bugs
- Look at PR #55336 pattern when working on similar autocomplete-related fixes
- Bug report templates live in `guides/bug_report_templates/`

## File Organization Principles

- `lib/` - Production code
- `test/` - Test files (NOT `spec/` - Rails uses Minitest, not RSpec)
- `bin/` - Executable scripts (e.g., `bin/test`)
- Each framework is self-contained with its own Gemfile and dependencies
- Shared tools live in `tools/` (e.g., `tools/test.rb`, `tools/release.rb`)

## Documentation
- API docs use YARD/RDoc format
- Guides source in `guides/source/` (Markdown)
- Generate docs: `rake rdoc` (from framework directory)
- Configuration options documented in `guides/source/configuring.md`
