require "rails_helper"

RSpec.describe "Interactive admin consultation calendar", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:admin) { User.create!(email: "interactive-owner@example.com", password: "password123", admin: true) }
  let(:headers) { { "Turbo-Frame" => "consultation_calendar_dialog" } }

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    sign_in admin
  end
  after { travel_back }

  it "returns day details with bookings, private blocks and exceptional appointments" do
    block = ConsultationBlock.create!(starts_at: Time.zone.parse("2026-10-12 12:00"), ends_at: Time.zone.parse("2026-10-12 14:00"), all_day: false, note: "Poufna blokada")
    booking = Booking.create!(user: admin, package: create_package, name: "Marta", email: admin.email, starts_at: Time.zone.parse("2026-10-12 08:15"))
    slot = ConsultationSlot.create!(starts_at: Time.zone.parse("2026-10-12 16:00"))
    get day_admin_consultation_calendar_path(date: "2026-10-12", calendar_date: "2026-10-01"), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="consultation_calendar_dialog"', "Poufna blokada", admin_booking_path(booking), edit_admin_consultation_block_path(block).split("?").first, edit_admin_consultation_slot_path(slot).split("?").first)
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "renders single forms in the dialog while keeping standalone pages available" do
    get new_admin_consultation_block_path(date: "2026-10-12"), headers: headers
    expect(response.body).to include('id="consultation_calendar_dialog"', "Szczegóły dnia")
    expect(response.body).not_to include("<!DOCTYPE html>")
    get new_admin_consultation_block_path(date: "2026-10-12")
    expect(response.body).to include("<!DOCTYPE html>")
  end

  it "saves a batch as streams with conflict warnings and retains the viewed month" do
    booking = Booking.create!(user: admin, package: create_package, name: "Marta", email: admin.email, starts_at: Time.zone.parse("2027-03-01 08:15"), status: :confirmed)
    post bulk_admin_consultation_blocks_path, headers: headers, params: { calendar_date: "2026-10-01", consultation_block_batch: { dates: %w[2027-03-01 2027-03-02 2027-03-05], all_day: "1", category: "holiday", note: "Urlop" } }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(ConsultationBlock.count).to eq(2)
    expect(response.body).to include('target="consultation_calendar_month"', 'target="consultation_calendar_lists"', 'data-month-date="2026-10-01"', admin_booking_path(booking), "Rezerwacje pozostają aktywne")
    expect(booking.reload).to be_confirmed
  end

  it "keeps invalid batch dates, notes and errors in the dialog without writing" do
    expect do
      post bulk_admin_consultation_blocks_path, headers: headers, params: { consultation_block_batch: { dates: %w[2027-03-01 2027-03-02], all_day: "0", start_time: "12:00", end_time: "09:00", note: "Zachowaj notatkę" } }
    end.not_to change(ConsultationBlock, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('id="consultation_calendar_dialog"', "Zachowaj notatkę", "2027-03-01", "Koniec musi być później")
  end

  it "returns validation errors for a single form inside the dialog" do
    post admin_consultation_slots_path, headers: headers, params: { dialog_date: "2026-10-12", calendar_date: "2026-10-01", consultation_slot: { date: "2026-10-12", hour: "08:30" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('id="consultation_calendar_dialog"', "Szczegóły dnia", "nakłada się")
  end

  it "refreshes after editing and deleting existing blocks in the dialog" do
    block = ConsultationBlock.create!(starts_at: Time.zone.parse("2027-03-01"), ends_at: Time.zone.parse("2027-03-02"))
    delete admin_consultation_block_path(block), headers: headers, params: { calendar_date: "2026-10-01" }
    expect(response.body).to include('target="consultation_calendar_month"', 'data-month-date="2026-10-01"')
    expect(ConsultationBlock.exists?(block.id)).to be false
  end

  it "protects the new read and write endpoints from non-admins" do
    admin.update!(admin: false)
    get day_admin_consultation_calendar_path(date: "2026-10-12"), headers: headers
    expect(response).to redirect_to(root_path)
    expect do
      post bulk_admin_consultation_blocks_path, headers: headers, params: { consultation_block_batch: { dates: [ "2027-03-01" ] } }
    end.not_to change(ConsultationBlock, :count)
    expect(response).to redirect_to(root_path)
  end
end
