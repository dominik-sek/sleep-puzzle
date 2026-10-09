class OrderItemsController < ApplicationController
  before_action :authenticate_user!

  def playback
    item = current_user.accessible_order_items.find(params[:id])
    item.order.with_lock do
      item.reload
      return head :forbidden if item.refunded_at? || !item.order.paid? || !item.first_stream_issued_at?

      item.update!(first_played_at: Time.current) unless item.first_played_at?
    end
    head :no_content
  end
end
