module Purchasable
  extend ActiveSupport::Concern

  included do
    validates :paddle_price_id, presence: true
  end
end
