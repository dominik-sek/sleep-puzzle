# Closing the Paddle overlay without paying fires no webhook at all, and the
# browser only reports it when the tab survives long enough to say so. Without
# this sweep those orders stay pending forever, and a pending order holds its
# products out of the shop - so a buyer who walked away mid-checkout could never
# buy those files again.
#
# Canceled rather than destroyed, unlike orders#abandon. That path has the buyer
# telling us they closed the overlay; this one is a clock running out, and a late
# transaction.completed still has to find a row to mark paid rather than log
# money nobody can account for.
class ReleaseAbandonedOrdersJob < ApplicationJob
  queue_as :default

  # Matches ReleaseAbandonedBookingsJob. Long enough that a slow-but-real payment
  # is never cut off; raise it well past their settlement window before enabling
  # any of Paddle's delayed methods.
  ABANDON_AFTER = 1.hour

  def perform
    Order.stale(ABANDON_AFTER.ago).find_each do |order|
      order.fail_payment!(:canceled)
      Rails.logger.info("Released abandoned order #{order.id}")
    rescue => e
      # one unreleasable order must not strand every later one in the batch
      Rails.logger.error("Failed to release abandoned order #{order.id}: #{e.message}")
    end
  end
end
