# frozen_string_literal: true

require 'faktory_worker_ruby'
require 'faktory/testing'
Faktory::Testing.blockless_inline_is_a_bad_idea_but_I_wanna_do_it_anyway!
ActiveJob::Base.queue_adapter = :faktory
