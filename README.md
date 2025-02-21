# SyntaxTree::ERB

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
- Vue
  - Attributes, events and slots using `:`, `@` and `#` respectively
- Text output

## Unhandled cases

- Please add to this pinned issue (https://github.com/davidwessman/syntax_tree-erb/issues/28) or create a separate issue if you encounter formatting or parsing errors.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "w_syntax_tree-erb", "~> 0.12", require: false
```

> I added the `w_` prefix to avoid conflicts if there will ever be an official `syntax_tree-erb` gem.

## Usage

### Parsing

```sh
bundle exec stree ast --plugins=erb "./**/*.html.erb"
```

### Format

```sh
bundle exec stree write --plugins=erb "./**/*.html.erb"
```

### In code

```ruby
require "syntax_tree/erb"

pp SyntaxTree::ERB.parse(source) # print out the AST
puts SyntaxTree::ERB.format(source) # format the AST
```

## List all parsing errors

In order to get a list of all parsing errors (which needs to be fixed before the formatting works), this script can be used:

```ruby
#!/bin/ruby

require "syntax_tree/erb"

failures = []

Dir
  .glob("./app/**/*.html.erb")
  .each do |file|
    puts("Processing #{file}")
    begin
      source = SyntaxTree::ERB.read(file)
      SyntaxTree::ERB.parse(source)
      SyntaxTree::ERB.format(source)
    rescue => exception
      failures << { file: file, message: exception.message }
    end
  end

puts failures
```

## Development

Install `husky`:

```sh
npm i -g husky
```

Setup linting:

```sh
npm run prepare
```

Install dependencies and run tests:

```sh
bundle
bundle exec rake
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/davidwessman/syntax_tree-erb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
