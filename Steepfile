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
    # The bundled stdlib RBS types `Kernel#__dir__` as `String?`, so passing it
    # to `File.expand_path` (which it is used for at file/module scope, where it
    # is never nil) trips ArgumentTypeMismatch. Reopening `Kernel` to narrow the
    # return type is rejected by RBS as a duplicate definition, so this is
    # demoted to a hint to clear that single false positive.
    hash[Steep::Diagnostic::Ruby::ArgumentTypeMismatch] = :hint
  end
end
