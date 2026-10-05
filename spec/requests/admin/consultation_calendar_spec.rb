require "rails_helper"

RSpec.describe "Admin consultation calendar", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:admin) { User.create!(email: "calendar-admin@example.com", password: "password123", admin: true) }
  let(:settings) { ConsultationSetting.current }

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    sign_in admin
  end
  after { travel_back }

  it "renders the calendar and settings with arbitrary future navigation" do
    get admin_consultation_calendar_path(date: "2027-12-20")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2027-12-20", "Blokady", "Harmonogram i ustawienia")
    get edit_admin_consultation_settings_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("08:15", "20:30", "Przejdź na dostępność z aplikacji")
  end

  it "rejects non-admin reads and writes" do
    admin.update!(admin: false)
    get admin_consultation_calendar_path
    expect(response).to redirect_to(root_path)
    expect { post admin_consultation_blocks_path, params: { consultation_block: { start_date: "2027-03-01", end_date: "2027-03-05", all_day: "1", category: "time_off" } } }.not_to change(ConsultationBlock, :count)
    expect(response).to redirect_to(root_path)
    patch admin_consultation_settings_path, params: { consultation_setting: { booking_window_months: 12 } }
    expect(response).to redirect_to(root_path)
  end

  it "creates, edits and removes a distant inclusive all-day block" do
    post admin_consultation_blocks_path, params: { consultation_block: { start_date: "2027-03-01", end_date: "2027-03-05", all_day: "1", category: "time_off", note: "Urlop prywatny" } }
    block = ConsultationBlock.last
    expect(block.starts_at).to eq(Time.zone.parse("2027-03-01 00:00"))
    expect(block.ends_at).to eq(Time.zone.parse("2027-03-06 00:00"))
    get edit_admin_consultation_block_path(block)
    expect(response.body).to include('value="2027-03-05"')
    patch admin_consultation_block_path(block), params: { consultation_block: { start_date: "2027-03-01", end_date: "2027-03-01", all_day: "0", start_time: "09:00", end_time: "10:00", category: "external_booking" } }
    expect(block.reload.ends_at).to eq(Time.zone.parse("2027-03-01 10:00"))
    delete admin_consultation_block_path(block)
    expect(ConsultationBlock.exists?(block.id)).to be false
  end

  it "saves conflicting blocks with warnings without canceling bookings" do
    booking = Booking.create!(user: admin, package: create_package, name: "Marta", email: admin.email, starts_at: Time.zone.parse("2026-10-12 08:15"), status: :confirmed)
    post admin_consultation_blocks_path, params: { consultation_block: { start_date: "2026-10-12", end_date: "2026-10-12", all_day: "1", category: "holiday" } }
    follow_redirect!
    expect(response.body).to include("blokada obejmuje istniejące konsultacje", admin_booking_path(booking))
    expect(booking.reload).to be_confirmed
  end

  it "rejects invalid ranges without losing submitted values" do
    post admin_consultation_blocks_path, params: { consultation_block: { start_date: "2027-03-05", end_date: "2027-03-01", all_day: "1", category: "time_off", note: "Moja notatka" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Moja notatka", 'value="2027-03-05"')
  end

  it "adds, edits and removes exceptional slots while rejecting overlaps" do
    post admin_consultation_slots_path, params: { consultation_slot: { date: "2026-10-17", hour: "10:00" } }
    slot = ConsultationSlot.last
    expect(slot.starts_at).to eq(Time.zone.parse("2026-10-17 10:00"))
    post admin_consultation_slots_path, params: { consultation_slot: { date: "2026-10-17", hour: "10:30" } }
    expect(response).to have_http_status(:unprocessable_entity)
    post admin_consultation_slots_path, params: { consultation_slot: { date: "2026-10-12", hour: "09:00" } }
    expect(response).to have_http_status(:unprocessable_entity)
    patch admin_consultation_slot_path(slot), params: { consultation_slot: { date: "2026-10-17", hour: "12:00" } }
    expect(slot.reload.starts_at.hour).to eq(12)
    delete admin_consultation_slot_path(slot)
    expect(ConsultationSlot.exists?(slot.id)).to be false
  end

  it "updates weekly hours and rejects overlaps atomically" do
    slot = settings.weekly_slots.find_by!(weekday: 1)
    patch admin_consultation_settings_path, params: { consultation_setting: { booking_window_months: 3, minimum_notice_hours: 48, weekly_slots_attributes: { "0" => { id: slot.id, time_of_day: "10:00", weekday: 1 }, "1" => { weekday: 1, time_of_day: "10:30" } } } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(slot.reload.time_of_day).to eq("08:15")
    expect(settings.reload.booking_window_months).to eq(2)
    patch admin_consultation_settings_path, params: { consultation_setting: { booking_window_months: 3, minimum_notice_hours: 48, weekly_slots_attributes: { "0" => { id: slot.id, time_of_day: "10:00", weekday: 1 } } } }
    expect(response).to redirect_to(admin_consultation_calendar_path)
    expect(slot.reload.time_of_day).to eq("10:00")
    expect(settings.reload.minimum_notice_hours).to eq(48)
  end

  it "allows swapping two existing hours in one atomic save" do
    first, second = settings.weekly_slots.where(weekday: 3).order(:minute_of_day).to_a
    patch admin_consultation_settings_path, params: { consultation_setting: { weekly_slots_attributes: {
      "0" => { id: first.id, weekday: 3, time_of_day: second.time_of_day },
      "1" => { id: second.id, weekday: 3, time_of_day: first.time_of_day }
    } } }
    expect(response).to redirect_to(admin_consultation_calendar_path)
    expect(first.reload.time_of_day).to eq("20:30")
    expect(second.reload.time_of_day).to eq("08:15")
  end

  it "requires explicit migration acknowledgement and ignores posted source flags" do
    patch admin_consultation_settings_path, params: { consultation_setting: { local_availability: true } }
    expect(settings.reload.local_availability?).to be false
    patch activate_local_admin_consultation_settings_path
    expect(settings.reload.local_availability?).to be false
    patch activate_local_admin_consultation_settings_path, params: { blocks_migrated: "1" }
    expect(settings.reload.local_availability?).to be true
  end
end
