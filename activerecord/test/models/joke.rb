# frozen_string_literal: true

class Joke < ActiveRecord::Base
  self.table_name = "funny_jokes"
end

class GoodJoke < ActiveRecord::Base
  self.table_name = "funny_jokes"
end
