# SyntaxTree::XML

[![Build Status](https://github.com/davidwessman/syntax_tree-erb/actions/workflows/main.yml/badge.svg)](https://github.com/davidwessman/syntax_tree-erb/actions/workflows/main.yml)

[Syntax Tree](https://github.com/ruby-syntax-tree/syntax_tree) support for ERB.

Currently handles

- ERB
  - Tags with and without output
  - Tags inside strings
  - `if`, `elsif`, `else` and `unless` statements
  - blocks
  - comments
  - Formatting of the ruby-code is done by `syntax_tree`
- HTML
  - Tags with attributes
  - Tags with and without closing tags
  - Comments
- Text output

## Unhandled cases

- `case` statements
- Create issue if you find more with a minimal example

## Installation

Add this line to your application's Gemfile:

```ruby
gem "syntax_tree-erb", github: "davidwessman/syntax_tree-erb", require: false
```

## Usage

```sh
bundle exec stree --plugins=erb "./**/*.html.erb"
```

From code:

```ruby
require "syntax_tree/erb"

pp SyntaxTree::ERB.parse(source) # print out the AST
puts SyntaxTree::ERB.format(source) # format the AST
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/davidwessman/syntax_tree-erb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
