require 'helper'

module Arel
  class FakeCrudder < SelectManager
    class FakeEngine
      attr_reader :calls, :connection_pool, :spec, :config

      def initialize
        @calls = []
        @connection_pool = self
        @spec = self
        @config =  { :adapter => 'sqlite3' }
      end

      def connection; self end

      def method_missing name, *args
        @calls << [name, args]
      end
    end

    include Crud

    attr_reader :engine
    attr_accessor :ctx

    def initialize engine = FakeEngine.new
      super
    end
  end

  describe 'crud' do
    describe 'insert' do
      it 'should call insert on the connection' do
        table = Table.new :users
        fc = FakeCrudder.new
        fc.from table
        fc.insert [[table[:id], 'foo']]
        fc.engine.calls.find { |method, _|
          method == :insert
        }.wont_be_nil
      end
    end

    describe 'update' do
      it 'should call update on the connection' do
        table = Table.new :users
        fc = FakeCrudder.new
        fc.from table
        fc.update [[table[:id], 'foo']]
        fc.engine.calls.find { |method, _|
          method == :update
        }.wont_be_nil
      end
    end

    describe 'delete' do
      it 'should call delete on the connection' do
        table = Table.new :users
        fc = FakeCrudder.new
        fc.from table
        fc.delete
        fc.engine.calls.find { |method, _|
          method == :delete
        }.wont_be_nil
      end
    end
  end
end
