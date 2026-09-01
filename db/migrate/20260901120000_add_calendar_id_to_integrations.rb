class AddCalendarIdToIntegrations < ActiveRecord::Migration[8.0]
  def up
    add_column :integrations, :calendar_id, :string

    # Carries the env var forward, so a deploy that already had a calendar keeps
    # using it without anyone opening the panel.
    calendar_id = ENV["GOOGLE_CALENDAR_ID"].presence
    return if calendar_id.blank?

    execute(<<~SQL.squish)
      UPDATE integrations
      SET calendar_id = #{ActiveRecord::Base.connection.quote(calendar_id)}
      WHERE service_name = 'google_calendar'
    SQL
  end

  def down
    remove_column :integrations, :calendar_id
  end
end
