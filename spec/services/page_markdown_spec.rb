require "rails_helper"

RSpec.describe PageMarkdown do
  it "extracts main content without discarding section headings or attribution" do
    html = <<~HTML
      <html><body>
        <nav>Site navigation</nav>
        <main>
          <header><h1>Our programmes</h1></header>
          <p>A <strong>calmer</strong> evening.</p>
          <blockquote>Sleeping well.<footer>A parent</footer></blockquote>
          <ol><li>Start here</li><li>Keep going</li></ol>
          <nav>Pagination</nav>
          <svg><text>Decoration</text></svg>
          <span aria-hidden="true">Duplicate text</span>
          <script>tracking()</script><style>.hidden { display: none; }</style>
          <template>Dialog template</template>
        </main>
        <footer>Site footer</footer>
      </body></html>
    HTML

    markdown = described_class.call(html)

    expect(markdown).to include("# Our programmes", "**calmer**", "Sleeping well.", "A parent", "1. Start here", "2. Keep going")
    expect(markdown).not_to include("Site navigation", "Pagination", "Decoration", "Duplicate text", "tracking()", ".hidden", "Dialog template", "Site footer", "<")
  end

  it "falls back to the body for pages without a main element" do
    markdown = described_class.call('<html><body><header>Menu</header><h1>Sign in</h1><p>Welcome back.</p><footer>Links</footer></body></html>')

    expect(markdown).to eq("# Sign in\n\nWelcome back.\n")
  end
end
