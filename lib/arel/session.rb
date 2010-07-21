module Arel
  class Session
    @instance = nil

    def self.instance
      @instance || new
    end

    def self.start
      @instance ||= new
      yield @instance
    ensure
      @instance = nil
    end

    def create(insert)
      insert.call
    end

    def read(select)
      @read ||= {}
      key = select.object_id
      return @read[key] if @read.key? key
      @read[key] = select.call
    end

    def update(update)
      update.call
    end

    def delete(delete)
      delete.call
    end
  end
end
