require 'abstract_unit'
require 'action_dispatch/http/upload'
require 'action_controller/metal/strong_parameters'

class ProcFilterTest < ActiveSupport::TestCase

  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  test 'proc filters' do
    params = ActionController::Parameters.new(
      fridge: {
        height: '180',
        entities: {
          :'1' => {
            type: 'Fish',
            family: 'Salmonidae',
            smelly: 'true'
          },
          :'0' => {
            type: 'Juice',
            taste: 'Orange',
            dates: {
              expires_at: '2014-04-04'
            }
          }
        }
      }
    )

    permitted = params.permit(
      fridge: [
        :height,
        entities: ->(attributes) {
          if attributes[:type] == 'Fish'
            [:type, :family]
          elsif attributes[:type] == 'Juice'
            [:type, :taste, { dates: [:expires_at] }]
          end
        }
      ]
    )

    assert_not_nil permitted[:fridge][:entities][:'0'][:dates][:expires_at]
    assert_filtered_out permitted[:fridge][:entities][:'1'], :smelly
  end
end
