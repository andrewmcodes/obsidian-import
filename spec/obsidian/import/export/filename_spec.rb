# frozen_string_literal: true

RSpec.describe Obsidian::Import::Export::Filename do
  describe ".slugify" do
    {
      "Rails" => "rails",
      "Ruby on Rails" => "ruby-on-rails",
      "@changesets/cli" => "changesets-cli",
      "  Spaced  Out  " => "spaced-out",
      "Hello---World" => "hello-world",
      "Café del Mar" => "caf-del-mar",
      "100% Pure" => "100-pure"
    }.each do |input, expected|
      it "slugifies #{input.inspect} to #{expected.inspect}" do
        expect(described_class.slugify(input)).to eq(expected)
      end
    end

    it "falls back to 'untitled' for empty slugs" do
      expect(described_class.slugify("!!!")).to eq("untitled")
    end
  end

  describe ".unique" do
    around { |ex|
      Dir.mktmpdir { |d|
        @dir = d
        ex.run
      }
    }

    it "returns the plain name when free" do
      expect(described_class.unique(@dir, "rails")).to eq("rails.md")
    end

    it "appends numeric suffixes on collision" do
      FileUtils.touch(File.join(@dir, "rails.md"))
      FileUtils.touch(File.join(@dir, "rails-2.md"))
      expect(described_class.unique(@dir, "rails")).to eq("rails-3.md")
    end

    it "supports a secondary extension" do
      expect(described_class.unique(@dir, "rubocop", secondary: "gem")).to eq("rubocop.gem.md")
    end

    it "places the collision suffix before the secondary extension" do
      FileUtils.touch(File.join(@dir, "rubocop.gem.md"))
      expect(described_class.unique(@dir, "rubocop", secondary: "gem")).to eq("rubocop-2.gem.md")
    end
  end
end
