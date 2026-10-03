module Admin
  class TestimonialInvitationsController < BaseController
    def index
      @invitations = TestimonialInvitation.recent_first
    end

    def create
      invitation = TestimonialInvitation.new(recipient_label: params[:recipient_label])
      if invitation.save
        redirect_to admin_testimonial_invitations_path, notice: "Utworzono prywatny link do opinii."
      else
        redirect_to admin_testimonial_invitations_path, alert: invitation.errors.full_messages.to_sentence
      end
    end

    def approve
      invitation = TestimonialInvitation.find(params[:id])
      if invitation.approve!
        redirect_to admin_testimonial_invitations_path, notice: "Opinia została opublikowana. Możesz ją edytować w Treściach."
      else
        redirect_to admin_testimonial_invitations_path, alert: "Ta opinia nie czeka już na zatwierdzenie."
      end
    end

    def decline
      invitation = TestimonialInvitation.find(params[:id])
      if invitation.decline!
        redirect_to admin_testimonial_invitations_path, notice: "Odrzucono opinię."
      else
        redirect_to admin_testimonial_invitations_path, alert: "Ta opinia nie czeka już na zatwierdzenie."
      end
    end
  end
end
