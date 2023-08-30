# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Handle ERB-tags inside HTML-tags, like `<div <%= "class='foo'" %>>`

## [0.10.4] - 2023-08-28

- Avoid grouping single tags
- Handle multiline ERB-comments

## [0.10.3] - 2023-08-27

## Fixes

- Allows parsing ERB-tags with if, else and end in the same tag

```erb
<%= if true
  what
end %>
```

This opens the possibility for formatting all if-statements with SyntaxTree properly
and removes the fix where any if-statement was force to one line.

## [0.10.2] - 2023-08-22

### Fixes

- Handles formatting empty documents and removing leading new-linews in files with content.
- Removes trailing whitespace from char data if it is the last element in a document, block or group.

## [0.10.1] - 2023-08-20

### Added

- Allow `DOCTYPE` to be after other tags, to work with e.g. ERB-tags on first line.

## [0.10.0] - 2023-08-20

- Changes how whitespace and newlines are handled.
- Supports syntax like:

```erb
<%= part %> / <%= total %> (<%= percentage %>%)
```

## [0.9.5] - 2023-07-02

- Fixes ruby comment in ERB-tag included VoidStatement
  Example:

```erb
<% # this is a comment %>
```

Output:

```diff
-<%
-
-  # this is a comment
-%>
+<% # this is a comment %>
```

- Updates versions in Bundler

## [0.9.4] - 2023-07-01

- Inline even more empty HTML-tags

```diff
<three-word-component
  :attribute1
  :attribute2
  :attribute3="value"
->
-</three-word-component>
+></three-word-component>
```

## [0.9.3] - 2023-06-30

- Print empty html-tags on one line if possible

## [0.9.2] - 2023-06-30

- Handle whitespace in HTML-strings using ERB-tags

## [0.9.1] - 2023-06-28

- Handle formatting of multi-line ERB-tags with more than one statement.

## [0.9.0] - 2023-06-22

### Added

- 🎉 First version based on syntax_tree-xml 🎉.
- Can format a lot of .html.erb-syntax and works as a plugin to syntax_tree.
- This is still early and there are a lot of different weird syntaxes out there.

[unreleased]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.10.4...HEAD
[0.10.4]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.10.3...v0.10.4
[0.10.3]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.10.2...v0.10.3
[0.10.2]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.9.5...v0.10.0
[0.9.5]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.9.4...v0.9.5
[0.9.4]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/davidwessman/syntax_tree-erb/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/davidwessman/syntax_tree-erb/compare/419727a73af94057ca0980733e69ac8b4d52fdf4...v0.9.0
