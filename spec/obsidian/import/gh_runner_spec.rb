# frozen_string_literal: true

RSpec.describe Obsidian::Import::GhRunner do
  # A fake executor records the args it receives and returns a canned triple.
  def executor(stdout: "", stderr: "", success: true, &block)
    lambda do |args|
      block&.call(args)
      [stdout, stderr, instance_double(Process::Status, success?: success)]
    end
  end

  around do |example|
    # The shared spec_helper disables gh globally; these examples test the
    # runner itself, so re-enable it (the injected executor means no real gh).
    ENV.delete(described_class::DISABLE_ENV)
    example.run
  end

  describe "#available?" do
    it "is true when `gh auth status` succeeds" do
      runner = described_class.new(executor: executor(success: true))
      expect(runner.available?).to be(true)
    end

    it "is false when `gh auth status` fails (not authenticated)" do
      runner = described_class.new(executor: executor(success: false))
      expect(runner.available?).to be(false)
    end

    it "is false when gh is not installed (ENOENT)" do
      runner = described_class.new(executor: ->(_args) { raise Errno::ENOENT })
      expect(runner.available?).to be(false)
    end

    it "is false when explicitly disabled via the environment" do
      ENV[described_class::DISABLE_ENV] = "1"
      runner = described_class.new(executor: executor(success: true))
      expect(runner.available?).to be(false)
    ensure
      ENV.delete(described_class::DISABLE_ENV)
    end

    it "memoizes the result" do
      calls = 0
      runner = described_class.new(executor: executor { calls += 1 })
      2.times { runner.available? }
      expect(calls).to eq(1)
    end
  end

  describe "#get" do
    it "invokes `gh api` with a GET and parses JSON" do
      seen = nil
      runner = described_class.new(executor: executor(stdout: '{"full_name":"rails/rails"}') { |args| seen = args })
      result = runner.get("repos/rails/rails")
      expect(result).to eq("full_name" => "rails/rails")
      expect(seen).to eq(["api", "-X", "GET", "repos/rails/rails"])
    end

    it "passes query params as -f fields" do
      seen = nil
      runner = described_class.new(executor: executor(stdout: "{}") { |args| seen = args })
      runner.get("search/repositories", q: "rails", per_page: 10)
      expect(seen).to eq(["api", "-X", "GET", "search/repositories", "-f", "q=rails", "-f", "per_page=10"])
    end

    {404 => Obsidian::Import::NotFoundError,
     403 => Obsidian::Import::AuthenticationError,
     401 => Obsidian::Import::AuthenticationError,
     429 => Obsidian::Import::RateLimitError}.each do |code, error|
      it "maps an HTTP #{code} from gh's stderr to #{error}" do
        runner = described_class.new(executor: executor(stderr: "gh: Whoops (HTTP #{code})", success: false))
        expect { runner.get("repos/x/y") }.to raise_error(error)
      end
    end

    it "raises ResponseError for an unrecognized failure" do
      runner = described_class.new(executor: executor(stderr: "something broke", success: false))
      expect { runner.get("repos/x/y") }.to raise_error(Obsidian::Import::ResponseError, /failed/)
    end

    it "raises ResponseError on malformed JSON" do
      runner = described_class.new(executor: executor(stdout: "{not json", success: true))
      expect { runner.get("repos/x/y") }.to raise_error(Obsidian::Import::ResponseError, /malformed/)
    end
  end
end
