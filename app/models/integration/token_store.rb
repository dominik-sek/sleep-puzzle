class Integration::TokenStore
  def load(service_name)
    integration = Integration.find_by(service_name: service_name)
    return nil unless integration&.access_token.present?

    JSON.generate(
      access_token: integration.access_token,
      refresh_token: integration.refresh_token,
      expiration_time_millis: integration.expires_at.to_i * 1000
    )
  end

  def store(service_name, token_json)
    data = JSON.parse(token_json)
    Integration.find_or_initialize_by(service_name: service_name).update!(
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      expires_at: Time.at(data["expiration_time_millis"].to_i / 1000.0)
    )
  end

  def delete(service_name)
    Integration.find_by(service_name: service_name)&.destroy
  end
end
