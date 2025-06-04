# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is the main Ruby on Rails framework repository - a **monorepo** containing 12 framework components:

**Core components (in dependency order):**
- `activesupport/` - Ruby core extensions and utilities (foundation)
- `activemodel/` - Model abstractions (validations, serialization)
- `activerecord/` - ORM and database layer
- `actionview/` - View layer and template rendering
- `actionpack/` - Controllers, routing, HTTP handling
- `activejob/` - Background job framework
- `actionmailer/` - Email framework
- `actioncable/` - WebSocket framework
- `activestorage/` - File upload and cloud storage
- `actionmailbox/` - Incoming email handling
- `actiontext/` - Rich text content
- `railties/` - Rails application framework and CLI

**Additional components:**
- `guides/` - Documentation system
- `tools/` - Development utilities

Each component is a separate gem with its own gemspec, changelog, and test suite.

## Development Commands

### Testing
```bash
# Run all tests (default)
rake default

# Run specific framework tests
cd activerecord && rake test
cd actionpack && rake test

# Run isolated tests (each file in separate process)
rake test:isolated

# Test specific database adapters (ActiveRecord)
cd activerecord && rake test_mysql2
cd activerecord && rake test_postgresql  
cd activerecord && rake test_sqlite3

# Run single test file
cd activerecord && ruby test/cases/base_test.rb

# Smoke test specific frameworks
rake smoke[activerecord,false]  # isolated=false
rake smoke["activerecord actionpack",true]  # isolated=true
```

### Database Setup (ActiveRecord development)
```bash
cd activerecord
rake db:mysql:build      # Create MySQL test databases
rake db:postgresql:build # Create PostgreSQL test databases
rake db:mysql:drop       # Drop MySQL test databases
```

### Documentation
```bash
rake rdoc           # Generate API documentation
rake preview_docs   # Generate docs for preview (creates preview.tar.gz)
```

### Code Analysis
```bash
rake lines          # Generate line statistics
cd activerecord && rake lines  # Component-specific stats
```

## Testing Patterns

### Test Structure
- **Unit tests**: `test/cases/` (ActiveRecord) or `test/` (other components)
- **Integration tests**: Component-specific subdirectories
- **Fixtures**: `test/fixtures/` for test data
- **Helpers**: `test/support/` or similar for test utilities

### Running Tests
- Default test runner uses **Minitest**
- ActiveRecord tests against multiple adapters: mysql2, trilogy, postgresql, sqlite3
- Isolated testing runs each test file in a separate process
- CI integration with Buildkite for parallel test execution

### Test Files
- Test files end with `_test.rb`
- Helper files: `test_helper.rb`, `abstract_unit.rb`, `helper.rb`
- Each component has standardized test setup

## Component-Specific Notes

### ActiveRecord
- Multi-adapter support requires `ARCONN` environment variable
- Database-specific tests in `test/cases/adapters/`
- Encryption performance tests: `rake test:encryption:performance:sqlite3`
- Arel tests: `rake test:arel`

### ActionPack
- Includes both ActionController and ActionDispatch
- Routing tests, controller tests, middleware tests
- Integration with rack for HTTP handling

### Guides
- Markdown source in `guides/source/`
- Generated with custom Rails guide system
- Bug report templates in `guides/bug_report_templates/`

## Development Workflow

### Code Changes
1. Run component-specific tests first
2. Run isolated tests for critical changes
3. For ActiveRecord changes, test multiple database adapters
4. For cross-component changes, run full test suite

### Multi-Database Testing (ActiveRecord)
ActiveRecord tests run against multiple databases by default. Individual adapter testing:
```bash
cd activerecord
rake mysql2:test      # Test only MySQL
rake postgresql:test  # Test only PostgreSQL
rake sqlite3:test     # Test only SQLite
```

### Framework Dependencies
- Changes to ActiveSupport may affect all other components
- ActiveModel changes affect ActiveRecord and form helpers
- ActionPack changes may affect ActionView integration