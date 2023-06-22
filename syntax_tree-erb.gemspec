# frozen_string_literal: true

require_relative "lib/syntax_tree/erb/version"

Gem::Specification.new do |spec|
  spec.name = "w_syntax_tree-erb"
  spec.version = SyntaxTree::ERB::VERSION
  spec.authors = ["Kevin Newton", "David Wessman"]
  spec.email = %w[kddnewton@gmail.com david@wessman.co]

  spec.summary = "Syntax Tree support for ERB"
  spec.homepage = "https://github.com/davidwessman/syntax_tree-erb"
  spec.license = "MIT"
  spec.metadata = { "rubygems_mfa_required" => "true" }

  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0")
        .reject { |f| f.match(%r{^(test|spec|features)/}) }
    end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]

  spec.add_dependency "prettier_print", ">= 1.2.0"
  spec.add_dependency "syntax_tree", ">= 6.1.1"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "simplecov"
end
