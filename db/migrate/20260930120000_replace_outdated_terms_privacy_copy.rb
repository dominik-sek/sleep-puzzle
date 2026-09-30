class ReplaceOutdatedTermsPrivacyCopy < ActiveRecord::Migration[8.1]
  class LegacyClause < ActiveRecord::Base
    self.table_name = "content_items"
  end

  REPLACEMENTS = {
    "7. Dane osobowe" => {
      "pl" => "Informacje o przetwarzaniu danych osobowych, w tym danych otrzymywanych z Google, znajdują się w Polityce prywatności dostępnej pod adresem /privacy.",
      "en" => "Details of personal data processing, including data received from Google, are in the Privacy policy at /en/privacy."
    },
    "8. Pliki cookies" => {
      "pl" => "Informacje o plikach cookies i usługach zewnętrznych znajdują się w Polityce prywatności dostępnej pod adresem /privacy.",
      "en" => "Details of cookies and external services are in the Privacy policy at /en/privacy."
    }
  }.freeze

  def up
    LegacyClause.where(collection_key: "terms.clauses").find_each do |clause|
      values = clause.values.deep_dup
      heading = values.dig("heading", "pl")
      replacement = REPLACEMENTS[heading]
      next unless replacement

      body = values.fetch("body", {})
      changed = false

      if heading == "7. Dane osobowe" && body.fetch("pl", "").include?("[DO UZUPEŁNIENIA")
        body["pl"] = replacement.fetch("pl")
        changed = true
      elsif heading == "8. Pliki cookies" && body.fetch("pl", "").include?("Pozostałe pliki pojawiają się tylko")
        body["pl"] = replacement.fetch("pl")
        changed = true
      end

      if heading == "7. Dane osobowe" && body.fetch("en", "").include?("[TO BE COMPLETED")
        body["en"] = replacement.fetch("en")
        changed = true
      elsif heading == "8. Pliki cookies" && body.fetch("en", "").include?("Anything beyond that appears only")
        body["en"] = replacement.fetch("en")
        changed = true
      end

      clause.update_columns(values: values, updated_at: Time.current) if changed
    end
  end

  def down
    # The old copy contained unverified claims and unpublished controller details.
  end
end
