# frozen_string_literal: true

module Admin
  # The blog: long-form articles the owner writes, drafts and publishes. Articles
  # carry no price, so unlike packages and products this is a plain CRUD rather
  # than a Purchasable screen; it reuses the same translated-input and
  # publication-field partials and the shared table/pagination components.
  class ArticlesController < BaseController
    before_action :load_article, only: %i[edit update destroy]

    def index
      @pagy, @articles = pagy(Article.order(created_at: :desc).with_attached_cover_image)
    end

    def new
      @article = Article.new
    end

    def create
      @article = Article.new

      if save_article
        redirect_to admin_articles_path, notice: "Dodano artykuł „#{@article.title}”."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if save_article
        redirect_to admin_articles_path, notice: "Zapisano zmiany w „#{@article.title}”."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @article.destroy
        redirect_to admin_articles_path, notice: "Usunięto artykuł „#{@article.title}”."
      else
        redirect_to admin_articles_path, alert: @article.errors.full_messages.to_sentence
      end
    end

    # Renders the article as it will appear publicly, from the unsaved form state,
    # so the owner can check formatting and language before publishing.
    def preview
      @article = Article.new(article_params)
      assign_translations
      assign_body

      locale = params[:preview_locale].presence_in(Translatable::LOCALES.map(&:to_s)) || I18n.default_locale.to_s
      I18n.with_locale(locale) do
        render partial: "preview", locals: { article: @article }
      end
    end

    private

    def load_article
      @article = Article.find(params[:id])
    end

    def save_article
      @article.assign_attributes(article_params)
      assign_translations
      assign_body

      cover = params.dig(:record, :cover_image)
      @article.cover_image.attach(cover) if cover.present?

      @article.save
    end

    def article_params
      params.require(:record).permit(:slug, :published, :published_at)
    end

    # Written field by field from the model's own declaration rather than
    # mass-assigned, like Admin::ContentBlocksController and the catalogue screens:
    # `translations` is a jsonb column, so permitting it wholesale would let a
    # forged form put anything at all in there.
    def assign_translations
      submitted = params.dig(:record, :translations)
      return if submitted.blank?

      Article.translated_fields.each do |field|
        Translatable::LOCALES.each do |locale|
          value = submitted.dig(field, locale.to_s)
          @article.assign_translation(field, locale, value) unless value.nil?
        end
      end
    end

    # The long-form body is Action Text, one record per locale, so it is assigned
    # separately from the jsonb translations.
    def assign_body
      submitted = params.dig(:record, :body)
      return if submitted.blank?

      Translatable::LOCALES.each do |locale|
        value = submitted[locale.to_s]
        next if value.nil?

        @article.public_send(:"body_#{locale}=", value)
      end
    end
  end
end
