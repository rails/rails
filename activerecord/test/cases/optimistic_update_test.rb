# frozen_string_literal: true

require "cases/helper"
require "models/computer"
require "models/person"
require "models/reader"
require "models/sharded/blog_post"
require "models/sharded/comment"

class OptimisticUpdateTest < ActiveRecord::TestCase
  fixtures :people, :sharded_blog_posts, :sharded_comments, :computers, :readers

  def test_it_works_with_block_syntax_and_optimistic_locking
    person = people(:michael)

    update_sql = capture_sql { person.update_if(primary_contact_id: 2) { person.update!(first_name: "Pierre") } }.first

    assert_match(/WHERE .*.lock_version. = .{1,2}.*.primary_contact_id. = .{1,2}/i, update_sql)
    assert_equal "Pierre", person.first_name
    assert_equal(%w(first_name lock_version updated_at), person.previous_changes.keys.sort)
  end

  def test_it_works_with_block_syntax
    post = sharded_blog_posts(:great_post_blog_one)

    update_sql = capture_sql { post.update_if(title: post.title) { post.update!(title: "New Title!") } }.first

    assert_match(/WHERE .*.title. = .{1,2}/i, update_sql)
    assert_equal "New Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_it_does_not_update_with_block_syntax
    post = sharded_blog_posts(:great_post_blog_one)
    sql_log = []
    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      capture_sql(sql_log) do
        post.update_if(title: "Not the current title") { post.update!(title: "New Title!") }
      end
    end
    update_sql = sql_log.first

    regexp = error_message_regexp(Sharded::BlogPost, ["sharded_blog_posts.title"])
    assert_match(regexp, error.message)
    assert_match(/WHERE .*.title. = .{1,2}/i, update_sql)
    assert_equal({}, post.previous_changes)
  end

  def test_it_does_not_update_if_stale
    michael = people(:michael)
    Person.find(michael.id).touch
    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      michael.update_if(primary_contact_id: 2) do
        michael.update!(first_name: "Pierre")
      end
    end

    regexp = error_message_regexp(Person, ["people.primary_contact_id", /lock_version = 0/])
    assert_match regexp, error.message
  end

  def test_it_works_with_inline_syntax
    post = sharded_blog_posts(:great_post_blog_one)

    post.update_if(title: post.title)
    update_sql = capture_sql { post.update!(title: "New Title!") }.first

    assert_match(/WHERE .*.title. = .{1,2}/i, update_sql)
    assert_equal "New Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_it_works_with_chained_syntax
    post = sharded_blog_posts(:great_post_blog_one)

    update_sql = capture_sql { post.update_if(title: post.title).update!(title: "New Title!") }.first

    assert_match(/WHERE .*.title. = .{1,2}/i, update_sql)
    assert_equal "New Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_it_does_not_update_with_inline_syntax
    post = sharded_blog_posts(:great_post_blog_one)
    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      post.update_if(title: "Not the current title")
      post.update_if(id: 123)
      post.update_if("id = ?", "456")
      post.update!(title: "New Title!")
    end

    regexp = error_message_regexp(Sharded::BlogPost, ["sharded_blog_posts.title", "sharded_blog_posts.id", /\(id = '456'\)/])
    assert_match(regexp, error.message)
  end

  def test_it_does_not_update_with_chained_syntax
    post = sharded_blog_posts(:great_post_blog_one)
    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      post.update_if(title: "").update!(title: "New Title!")
    end

    regexp = error_message_regexp(Sharded::BlogPost, ["sharded_blog_posts.title"])
    assert_match(regexp, error.message)
  end

  def test_it_can_clear_conditions
    post = sharded_blog_posts(:great_post_blog_one)
    post.update_if(title: post.title)
    post.update!(title: "New Title!")
    assert_equal "New Title!", post.title

    post.clear_update_conditions
    update_sql = capture_sql { post.update!(title: "Latest Title!") }.first

    assert_no_match(/WHERE .*.title. = .{1,2}/i, update_sql)
    assert_equal "Latest Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_block_syntax_automatically_clear_conditions
    post = sharded_blog_posts(:great_post_blog_one)
    post.update_if(title: post.title) { post.update!(title: "New Title!") }
    assert_equal "New Title!", post.title

    update_sql = capture_sql { post.update!(title: "Latest Title!") }.first

    assert_no_match(/WHERE .*.title. = .{1,2}/i, update_sql)
    assert_equal "Latest Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_supports_where_syntax
    post = sharded_blog_posts(:great_post_blog_one)

    update_sql = capture_sql { post.update_if("title = ?", post.title) { post.update!(title: "New Title!") } }.first

    assert_match(/WHERE .*\(title = 'My first post!'\)/i, update_sql)
    assert_equal "New Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_it_can_stack_conditions
    comment = sharded_comments(:great_comment_blog_post_one)

    update_sql = capture_sql do
      comment.update_if("blog_post_id = ?", comment.blog_post_id.to_s) do
        comment.update_if(body: comment.body) { comment.update!(body: "New Body!") }
      end
    end.first

    assert_match(/WHERE .*blog_post_id = '#{comment.blog_post_id}'.*.body. = .{1,2}/i, update_sql)
    assert_equal "New Body!", comment.body
    assert_equal(%w(body), comment.previous_changes.keys)
  end

  def test_like_syntax
    post = sharded_blog_posts(:great_post_blog_one)

    update_sql = capture_sql { post.update_if("title LIKE ?", "%first%") { post.update!(title: "New Title!") } }.first

    assert_match(/WHERE .*title LIKE '%first%'/i, update_sql)
    assert_equal "New Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_interpolation_with_hash_syntax
    post = sharded_blog_posts(:great_post_blog_one)

    update_sql = capture_sql { post.update_if("title = :title", title: post.title) { post.update!(title: "New Title!") } }.first

    assert_match(/WHERE .*\(title = 'My first post!'\)/i, update_sql)
    assert_equal "New Title!", post.title
    assert_equal(%w(title), post.previous_changes.keys)
  end

  def test_like_syntax_no_update
    post = sharded_blog_posts(:great_post_blog_one)
    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      post.update_if("title LIKE ?", "%no match%") do
        post.update!(title: "New Title!")
      end
    end

    regexp = error_message_regexp(Sharded::BlogPost, [/\(title LIKE '%no match%'\)/i])
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_touch
    computer = computers(:workstation)
    original_updated_at = computer.updated_at

    update_sql = capture_sql { computer.update_if(system: computer.system) { computer.touch } }.first

    assert_match(/WHERE .*.system. = .{1,2}/i, update_sql)
    assert_not_equal original_updated_at, computer.reload.updated_at
  end

  def test_it_raises_when_not_matching_with_touch
    computer = computers(:workstation)
    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      computer.update_if(system: "macOS") do
        computer.touch
      end
    end

    regexp = error_message_regexp(Computer, ["computers.system"], "touch")
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_increment!
    computer = computers(:workstation)
    original_timezone = computer.timezone

    update_sql = capture_sql { computer.update_if(system: computer.system) { computer.increment!(:timezone) } }.first

    assert_match(/WHERE .*.system. = .{1,2}/i, update_sql)
    assert_not_equal original_timezone, computer.timezone
  end


  def test_it_raises_when_not_matching_with_increment!
    computer = computers(:workstation)

    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      computer.update_if(system: "macOS") { computer.increment!(:timezone) }
    end

    regexp = error_message_regexp(Computer, ["computers.system"], "increment!")
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_decrement!
    computer = computers(:workstation)
    original_timezone = computer.timezone

    update_sql = capture_sql { computer.update_if(system: computer.system) { computer.decrement!(:timezone) } }.first

    assert_match(/WHERE .*.system. = .{1,2}/i, update_sql)
    assert_not_equal original_timezone, computer.timezone
  end


  def test_it_raises_when_not_matching_with_decrement!
    computer = computers(:workstation)

    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      computer.update_if(system: "macOS") { computer.decrement!(:timezone) }
    end

    regexp = error_message_regexp(Computer, ["computers.system"], "decrement!")
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_toggle!
    reader = readers(:michael_welcome)

    update_sql = capture_sql { reader.update_if(person_id: reader.person_id) { reader.toggle!(:skimmer) } }.first

    assert_match(/WHERE .*.person_id. = .{1,2}/i, update_sql)
    assert reader.skimmer
  end

  def test_it_raises_when_not_matching_with_toggle!
    reader = readers(:michael_welcome)

    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      reader.update_if(person_id: -1) { reader.toggle!(:skimmer) }
    end

    regexp = error_message_regexp(Reader, ["readers.person_id"])
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_update_attribute
    reader = readers(:michael_welcome)

    update_sql = capture_sql { reader.update_if(person_id: reader.person_id) { reader.update_attribute(:skimmer, true) } }.first

    assert_match(/WHERE .*.person_id. = .{1,2}/i, update_sql)
    assert reader.skimmer
  end

  def test_it_raises_when_not_matching_with_update_attribute
    reader = readers(:michael_welcome)

    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      reader.update_if(person_id: -1) { reader.update_attribute(:skimmer, true) }
    end

    regexp = error_message_regexp(Reader, ["readers.person_id"])
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_update_column
    reader = readers(:michael_welcome)

    update_sql = capture_sql { reader.update_if(person_id: reader.person_id) { reader.update_column(:skimmer, true) } }.first

    assert_match(/WHERE .*.person_id. = .{1,2}/i, update_sql)
    assert reader.skimmer
  end

  def test_it_raises_when_not_matching_with_update_column
    reader = readers(:michael_welcome)

    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      reader.update_if(person_id: -1) { reader.update_column(:skimmer, true) }
    end

    regexp = error_message_regexp(Reader, ["readers.person_id"])
    assert_match(regexp, error.message)
  end

  def test_it_updates_with_update_columns
    reader = readers(:michael_welcome)

    update_sql = capture_sql { reader.update_if(person_id: reader.person_id) { reader.update_columns(skimmer: true) } }.first

    assert_match(/WHERE .*.person_id. = .{1,2}/i, update_sql)
    assert reader.skimmer
  end

  def test_it_raises_when_not_matching_with_update_columns
    reader = readers(:michael_welcome)

    error = assert_raises(ActiveRecord::UnexpectedValueInDatabase) do
      reader.update_if(person_id: -1) { reader.update_columns(skimmer: true) }
    end

    regexp = error_message_regexp(Reader, ["readers.person_id"])
    assert_match(regexp, error.message)
  end

  private
    def error_message_regexp(model, where_columns, operation = "update")
      connection = model.connection
      quoted_where_columns = where_columns.map do |where|
        if where.is_a?(Regexp)
          where
        else
          quoted_column_name = quote_column_name(connection, where)
          "#{quoted_column_name} = .*"
        end
      end.join(" AND ")

      /Failed to #{operation} an object: #{model}\. No rows matching \[WHERE #{quoted_where_columns}\]/
    end

    def quote_column_name(connection, column)
      Regexp.escape(connection.quote_table_name(column))
    end
end
