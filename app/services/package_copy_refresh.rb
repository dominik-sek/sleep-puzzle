# frozen_string_literal: true

# An explicit, repeatable copy update. Matching the original edited fields
# rather than a name or id protects later CMS edits and works across databases.
# No deployment hook runs this automatically.
class PackageCopyRefresh
  FIELDS = %w[for_whom highlights core extra organization].freeze
  SHARED_KEY = "packages.shared.body"

  def initialize(plan = JSON.parse(Rails.root.join("config/package_copy_refresh.json").read))
    @plan = plan
  end

  def preview
    resolve(Package.ordered.to_a).map do |package, entry|
      { id: package.id, name: package.name, changed: !matches?(package, entry.fetch("replacement")) }
    end
  end

  def apply!(backup_dir: Rails.root.join("backups"))
    backup_path = nil
    Package.transaction do
      packages = Package.ordered.lock.to_a
      resolved = resolve(packages)
      shared = ContentBlock.find_or_initialize_by(key: SHARED_KEY)
      shared.lock! if shared.persisted?
      expected_shared = @plan.fetch("shared_body_pl")
      if shared.body_pl.body.present? && shared.body_pl.body.to_html != ActionText::Content.new(expected_shared).to_html
        raise ArgumentError, "Wspólne zasady zostały już zredagowane. Nie nadpisano treści."
      end
      changed = resolved.reject { |package, entry| matches?(package, entry.fetch("replacement")) }
      next if changed.empty? && shared.body_pl.body.present?

      FileUtils.mkdir_p(backup_dir)
      backup_path = Pathname(backup_dir).join("package-copy-#{Time.current.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(4)}.json")
      snapshot = {
        packages: packages.map { |package| package.attributes.slice("id", "duration", "translations") },
        content_blocks: ContentBlock.where(key: [ SHARED_KEY, "packages.hero.subtitle", "packages.collaboration.body" ]).map do |block|
          { key: block.key, value_pl: block.value_pl, value_en: block.value_en,
            body_pl: block.body_pl.body&.to_html, body_en: block.body_en.body&.to_html }
        end
      }
      File.open(backup_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.pretty_generate(snapshot)) }

      changed.each do |package, entry|
        entry.fetch("replacement").each do |field, translations|
          translations.each do |locale, value|
            if Package.translated_list_fields.include?(field)
              package.assign_translation_list(field, locale, value)
            else
              package.assign_translation(field, locale, value)
            end
          end
        end
        package.save!
      end
      shared.body_pl = expected_shared
      shared.save!
    end
    backup_path
  end

  private

  def resolve(packages)
    resolved = @plan.fetch("packages").map do |entry|
      [ "expected", "replacement" ].each do |key|
        fields = entry.fetch(key)
        raise ArgumentError, "Nieznane pola treści" unless (fields.keys - FIELDS).empty?
        raise ArgumentError, "Nieznany język" unless fields.values.all? { |translations| (translations.keys - Translatable::LOCALES.map(&:to_s)).empty? }
      end
      candidates = packages.select do |package|
        package.duration == entry.fetch("duration") &&
          (matches?(package, entry.fetch("expected")) || matches?(package, entry.fetch("replacement")))
      end
      raise ArgumentError, "Treść pakietu #{entry.fetch('label')} nie odpowiada przygotowanej redakcji. Nie nadpisano treści." unless candidates.one?

      [ candidates.first, entry ]
    end
    selected = resolved.map(&:first)
    raise ArgumentError, "Pakiet wskazano więcej niż raz" unless selected.uniq.size == selected.size
    raise ArgumentError, "Nowy opublikowany pakiet wymaga sprawdzenia wspólnych zasad" unless packages.select(&:published?).all? { |package| selected.include?(package) }

    resolved
  end

  def matches?(package, fields)
    fields.all? do |field, translations|
      translations.all? { |locale, value| package.raw_translation(field, locale) == value }
    end
  end
end
