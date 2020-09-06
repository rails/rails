# frozen_string_literal: true

require 'abstract_unit'
require 'action_dispatch'
require 'active_record'

class JsonParamsParsingTest < ActionDispatch::IntegrationTest
  def test_prevent_null_query
    # Make sure we have data to find
    klass = Class.new(ActiveRecord::Base) do
      def self.name; 'Foo'; end
      establish_connection adapter: 'sqlite3', database: ':memory:'
      connection.create_table 'foos' do |t|
        t.string :title
        t.timestamps null: false
      end
    end
    klass.create
    assert klass.first

    app = ->(env) {
      request = ActionDispatch::Request.new env
      params = ActionController::Parameters.new request.parameters
      if params[:t]
        klass.find_by_title(params[:t])
      else
        nil
      end
    }

    assert_nil app.call(make_env('t' => nil))
    assert_nil app.call(make_env('t' => [nil]))

    [[[nil]], [[[nil]]]].each do |data|
      assert_nil app.call(make_env('t' => data))
    end
  ensure
    klass.connection.drop_table('foos')
  end

  private
    def make_env(json)
      data = JSON.dump json
      content_length = data.length
      {
        'CONTENT_LENGTH' => content_length,
        'CONTENT_TYPE'   => 'application/json',
        'rack.input'     => StringIO.new(data)
      }
    end
end
