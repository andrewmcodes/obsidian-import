# frozen_string_literal: true

target :lib do
  signature "sig"

  check "lib"

  library "json"
  library "digest"
  library "pathname"
  library "yaml"
  library "uri"

  # Third-party gems ship without bundled RBS here; treat unresolved constants
  # from them leniently so signature work can proceed incrementally.
  configure_code_diagnostics(Steep::Diagnostic::Ruby.default) do |hash|
    hash[Steep::Diagnostic::Ruby::UnknownConstant] = :hint
    hash[Steep::Diagnostic::Ruby::NoMethod] = :hint
  end
end
