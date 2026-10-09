class PurchaseMailer < ApplicationMailer
  def confirmed
    @record = params[:record]
    @snapshot = @record.legal_snapshot
    @names = @record.is_a?(Order) ? @record.products.map(&:name) : [ @record.package.name ]
    mail to: @record.user.email, subject: @snapshot.fetch("subject")
  end
end
