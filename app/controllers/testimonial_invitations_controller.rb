class TestimonialInvitationsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :update, with: -> { head :too_many_requests }

  before_action :find_invitation

  def show
    @invitation = @testimonial_invitation
  end

  def update
    @invitation = @testimonial_invitation
    return render :show, status: :gone unless @invitation.open?

    if @invitation.submit!(submission_params.to_h.symbolize_keys, locale: I18n.locale)
      redirect_to testimonial_invitation_path(@invitation.token), notice: t("testimonials.submitted")
    else
      @invitation.status = "open"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def find_invitation
    @testimonial_invitation = TestimonialInvitation.find_by!(token: params[:token])
  end

  def submission_params
    params.fetch(:testimonial_invitation, ActionController::Parameters.new)
          .permit(:quote, :author, :publication_consent)
  end
end
