require 'rails_helper'

RSpec.describe 'Home', type: :system do
  it 'shows the homepage heading' do
    visit root_path
    expect(page).to have_content('Tailwind 4 + Vite works')
  end
end
