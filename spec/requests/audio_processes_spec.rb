require 'rails_helper'

RSpec.describe "Audio process landing", type: :request do
  it "shows one published audio process and a route to purchase" do
    create_product(name: "Bajka", kind: :bedtime_story)
    create_product(name: "Proces dla rodziców", kind: :audio_process)

    get audio_process_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Proces dla rodziców", "Dla kogo")
    expect(response.body).not_to include("Bajka")
  end

  it "shows a truthful empty state when no audio process is published" do
    get audio_process_path

    expect(response.body).to include("Audioproces pojawi się tutaj wkrótce")
  end
end
