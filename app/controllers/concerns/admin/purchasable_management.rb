# frozen_string_literal: true

module Admin
  # The CRUD shared by the two catalogue screens. Packages and products differ
  # only in which fields they carry, so each controller declares that and
  # inherits the rest.
  #
  # Translated values are written field by field from the model's own declaration
  # rather than mass-assigned, the way Admin::ContentBlocksController writes
  # collection items: `translations` is a jsonb column, so permitting it wholesale
  # would let a forged form put anything at all in there.
  module PurchasableManagement
    extend ActiveSupport::Concern

    class_methods do
      # @param model [Class] the Purchasable being managed
      # @param label [String] what one record is called, for the flash messages
      # @param plain_attributes [Array<Symbol>] non-translated columns on the form
      def manages(model, label:, plain_attributes: [])
        self.managed_model = model
        self.record_label = label
        self.plain_attributes = plain_attributes.map(&:to_sym).freeze
      end
    end

    included do
      class_attribute :managed_model, instance_writer: false
      class_attribute :record_label, instance_writer: false, default: "pozycję"
      class_attribute :plain_attributes, instance_writer: false, default: [].freeze

      before_action :load_record, only: %i[edit update destroy]
      before_action :load_prices, only: %i[index new create edit update]

      helper_method :managed_model, :record_label
    end

    def index
      @pagy, @records = pagy(managed_model.ordered)
    end

    def new
      @record = managed_model.new
    end

    def create
      @record = managed_model.new

      if save_record
        redirect_to index_path, notice: "Dodano #{record_label} „#{@record.name}”."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if save_record
        redirect_to index_path, notice: "Zapisano zmiany w „#{@record.name}”."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # restrict_with_error on Package#bookings: a package someone has booked is
      # history, and deleting it would take the booking's record of what was sold
      if @record.destroy
        redirect_to index_path, notice: "Usunięto „#{@record.name}”."
      else
        redirect_to index_path, alert: @record.errors.full_messages.to_sentence
      end
    end

    private

    def load_record
      @record = managed_model.find(params[:id])
    end

    def index_path
      polymorphic_path([ :admin, managed_model ])
    end

    # Fetched once per request and handed to the form and the index alike, so a
    # page listing twenty packages makes one Paddle call rather than twenty.
    def load_prices
      @prices = PaddlePriceCatalogService.call
    end

    def save_record
      @record.assign_attributes(plain_params)
      assign_translations

      @record.save
    end

    def assign_translations
      submitted = params.require(:record).fetch(:translations, nil)
      return if submitted.blank?

      managed_model.translated_fields.each do |field|
        Translatable::LOCALES.each do |locale|
          value = submitted.dig(field, locale.to_s)
          @record.assign_translation(field, locale, value) unless value.nil?
        end
      end

      # one bullet per line: a list editor with add/remove buttons would be a lot
      # of machinery for something the owner edits a handful of times a year
      managed_model.translated_list_fields.each do |field|
        Translatable::LOCALES.each do |locale|
          value = submitted.dig(field, locale.to_s)
          @record.assign_translation_list(field, locale, value.to_s.split("\n")) unless value.nil?
        end
      end
    end

    def plain_params
      params.require(:record).permit(*plain_attributes)
    end
  end
end
