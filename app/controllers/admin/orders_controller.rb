# frozen_string_literal: true

module Admin
  # Shop purchases. The panel is where "I paid and cannot see my audio" gets
  # answered, so the Paddle transaction id is carried through to the show page —
  # it is what a refund or a dispute is looked up by on Paddle's side.
  class OrdersController < BaseController
    def index
      @status = params[:status] if Order.statuses.key?(params[:status])

      scope = Order.includes(:user, order_items: :product).recent_first
      scope = scope.where(status: @status) if @status

      @pagy, @orders = pagy(scope)
    end

    # deliberately not scoped to current_user the way OrdersController#show is:
    # the panel exists to look at other people's orders
    def show
      @order = Order.includes(:user, order_items: :product).find_by!(token: params[:token])
    end
  end
end
