module Admin
  class AudioChaptersController < BaseController
    before_action :load_product
    before_action :load_chapter, only: %i[edit update destroy]

    def new
      @chapter = @product.audio_chapters.new(position: @product.audio_chapters.maximum(:position).to_i + 1)
    end

    def create
      @chapter = @product.audio_chapters.new(chapter_params)
      assign_titles
      if @chapter.save
        redirect_to edit_admin_product_audio_chapter_path(@product, @chapter), notice: "Dodano chapter. Teraz wgraj plik audio."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @chapter.assign_attributes(chapter_params)
      assign_titles
      if @chapter.save
        redirect_to edit_admin_product_path(@product), notice: "Zapisano chapter."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @product.order_items.exists?
        redirect_to edit_admin_product_path(@product), alert: "Nie można usunąć chapteru kupionego audioprocesu."
      else
        @chapter.destroy!
        redirect_to edit_admin_product_path(@product), notice: "Usunięto chapter."
      end
    end

    private

    def load_product
      @product = Product.audio_process.find(params[:product_id])
    end

    def load_chapter
      @chapter = @product.audio_chapters.find(params[:id])
    end

    def chapter_params
      params.require(:audio_chapter).permit(:position)
    end

    def assign_titles
      submitted = params.require(:audio_chapter).fetch(:translations, {})
      Translatable::LOCALES.each do |locale|
        value = submitted.dig("title", locale.to_s)
        @chapter.assign_translation(:title, locale, value) unless value.nil?
      end
    end
  end
end
