require "rails_helper"

RSpec.describe PackageCopyRefresh do
  let(:manifest) { JSON.parse(Rails.root.join("config/package_copy_refresh.json").read) }
  let(:refresh) { described_class.new(manifest) }

  before do
    manifest.fetch("packages").each_with_index do |entry, index|
      package = create_package(name: "Dowolna nazwa #{index}", duration: entry.fetch("duration"))
      entry.fetch("expected").each do |field, locales|
        locales.each do |locale, value|
          next if value.nil?
          if Package.translated_list_fields.include?(field)
            package.assign_translation_list(field, locale, value)
          else
            package.assign_translation(field, locale, value)
          end
        end
      end
      package.assign_translation(:organization, :en, "Existing English terms")
      package.save!
    end
  end

  it "previews without changes and backs up every original before applying" do
    originals = Package.ordered.map(&:translations)
    expect(refresh.preview.map { |item| item[:changed] }).to eq([ true, true, true ])
    expect(Package.ordered.map(&:translations)).to eq(originals)

    Dir.mktmpdir do |directory|
      backup = refresh.apply!(backup_dir: directory)
      expect(JSON.parse(backup.read).fetch("packages").map { |item| item.fetch("translations") }).to eq(originals)
      expect(File.stat(backup).mode & 0o777).to eq(0o600)
      Package.ordered.each_with_index do |package, index|
        expect(package.name).to eq("Dowolna nazwa #{index}")
        expect(package.highlights.size).to eq(5)
        expect(package.organization).to be_present
        expect(package.raw_translation(:organization, :en)).to eq("Existing English terms")
      end
      expect(ContentBlock.find_by!(key: "packages.shared.body").body_pl.to_plain_text).to include("Telegramie", "aktywnych tygodniach")
      expect(refresh.apply!(backup_dir: directory)).to be_nil
      expect(Dir.children(directory).size).to eq(1)
    end
  end

  it "refuses later edits without changing any package or writing a backup" do
    package = Package.ordered.last
    package.assign_translation(:for_whom, :pl, "Nowy opis administratora")
    package.save!
    originals = Package.ordered.map(&:translations)

    Dir.mktmpdir do |directory|
      expect { refresh.apply!(backup_dir: directory) }.to raise_error(ArgumentError, /Nie nadpisano/)
      expect(Dir.children(directory)).to be_empty
    end
    expect(Package.ordered.map(&:translations)).to eq(originals)
    expect(ContentBlock.find_by(key: "packages.shared.body")).to be_nil
  end

  it "refuses to declare common terms when a new published package was added" do
    create_package(name: "Nowy pakiet", duration: 10)
    expect { refresh.preview }.to raise_error(ArgumentError, /Nowy opublikowany pakiet/)
  end

  it "rolls all updates back when saving one fails, keeping the original backup" do
    originals = Package.ordered.map(&:translations)
    allow_any_instance_of(ContentBlock).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)

    Dir.mktmpdir do |directory|
      expect { refresh.apply!(backup_dir: directory) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Dir.children(directory).size).to eq(1)
    end
    expect(Package.ordered.map(&:translations)).to eq(originals)
  end
end
