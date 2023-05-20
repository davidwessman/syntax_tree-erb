# frozen_string_literal: true

module SyntaxTree
  module ERB
    class Parser
      NAME_START =
        "[@:a-zA-Z_\u{2070}-\u{218F}\u{2C00}-\u{2FEF}\u{3001}-\u{D7FF}\u{F900}-\u{FDCF}\u{FDF0}-\u{FFFD}]"

      NAME_CHAR =
        "[#{NAME_START}-\\.\\d\u{00B7}\u{0300}-\u{036F}\u{203F}-\u{2040}]"

      NAME = "#{NAME_START}(?:#{NAME_CHAR})*"

      # This is the parent class of any kind of errors that will be raised by
      # the parser.
      class ParseError < StandardError
      end

      # This error occurs when a certain token is expected in a certain place
      # but is not found. Sometimes this is handled internally because some
      # elements are optional. Other times it is not and it is raised to end the
      # parsing process.
      class MissingTokenError < ParseError
      end

      class ErbKeywordError < ParseError
      end

      # This error is thrown when an erb-tag with a do-statement is parsed.
      # It is used to control the flow of the parser.
      class ErbDoTokenError < ParseError
        attr_reader(:tag)

        def initialize(tag:)
          @tag = tag
        end
      end

      attr_reader :source, :tokens

      def initialize(source)
        @source = source
        @tokens = make_tokens
      end

      def parse
        elements = many { parse_any_tag }

        location =
          elements.first.location.to(elements.last.location) if elements.any?

        Document.new(elements: elements, location: location)
      end

      def debug_tokens
        @tokens.each do |key, value, index, line|
          puts("#{key} #{value.inspect} #{index} #{line}")
        end
      end

      private

      def parse_any_tag
        atleast do
          maybe { parse_erb_if } || maybe { parse_erb_tag } ||
            maybe { parse_html_element } || maybe { parse_chardata }
        end
      end

      def make_tokens
        Enumerator.new do |enum|
          index = 0
          line = 1
          state = %i[outside]

          while index < source.length
            case state.last
            in :outside
              case source[index..]
              when /\A(?: |\t|\n|\r\n)+/m
                # whitespace
                # enum.yield :whitespace, $&, index, line
                line += $&.count("\n")
              when /\A<!--(.|\r?\n)*?-->/m
                # comments
                # <!-- this is a comment -->
                enum.yield :comment, $&, index, line
                line += $&.count("\n")
              when /\A<!DOCTYPE/
                # document type tags
                # <!DOCTYPE
                enum.yield :doctype, $&, index, line
                state << :inside
              when /\A<%\s*else\s*%>/
                # ERB else statements
                # <% else %>
                enum.yield :erb_else, $&, index, line
                line += $&.count("\n")
              when /\A<%\s*elsif/
                # ERB elsif statements
                # <% elsif
                enum.yield :erb_elsif_open, $&, index, line
                state << :erb
                line += $&.count("\n")
              when /\A<%\s*if/
                # ERB if statements
                # <% if
                enum.yield :erb_if_open, $&, index, line
                state << :erb
                line += $&.count("\n")
              when /\A<%\s*unless/
                # ERB unless statements
                # <% unless
                enum.yield :erb_unless_open, $&, index, line
                state << :erb
                line += $&.count("\n")
              when /\A<%\s*end\s*%>/
                # ERB end statements
                # <% end %>
                enum.yield :erb_end, $&, index, line
                line += $&.count("\n")
              when /\A<%[=]?/
                # the beginning of an ERB tag
                # <%
                enum.yield :erb_open, $&, index, line
                state << :erb
                line += $&.count("\n")
              when %r{\A</}
                # the beginning of a closing tag
                # </
                enum.yield :slash_open, $&, index, line
                state << :inside
              when /\A</
                # the beginning of an opening tag
                # <
                enum.yield :open, $&, index, line
                state << :inside
              when /\A"/
                # the beginning of a string
                enum.yield :string_open, $&, index, line
                state << :string
              when /\A[^<&]+/
                # plain text content
                # abc
                enum.yield :text, $&, index, line
              else
                raise ParseError,
                      "Unexpected character at #{index}: #{source[index]}"
              end
            in :erb
              case source[index..]
              when /\A[\n]+/
                # whitespace
                line += $&.count("\n")
              when /\Ado\s*.*?\s*%>/
                enum.yield :erb_do_close, $&, index, line
                state.pop
              when /\A%>/
                enum.yield :erb_close, $&, index, line
                state.pop
              else
                enum.yield :erb_code, source[index], index, line
                index += 1
                next
              end
            in :string
              case source[index..]
              when /\A(?: |\t|\n|\r\n)+/m
                # whitespace
                enum.yield :whitespace, $&, index, line
                line += $&.count("\n")
              when /\A\"/
                # the end of a quoted string
                enum.yield :string_close, $&, index, line
                state.pop
              when /\A<%[=]?/
                # the beginning of an ERB tag
                # <%
                enum.yield :erb_open, $&, index, line
                state << :erb
              when /\A[^<&"]+/
                # plain text content
                # abc
                enum.yield :text, $&, index, line
              else
                raise ParseError,
                      "Unexpected character in string at #{index}: #{source[index]}"
              end
            in :inside
              case source[index..]
              when /\A[ \t\r\n]+/
                # whitespace
                line += $&.count("\n")
              when /\A%>/
                # the end of an ERB tag
                # %>
                enum.yield :erb_close, $&, index, line
                state.pop
              when /\A>/
                # the end of a tag
                # >
                enum.yield :close, $&, index, line
                state.pop
              when /\A\?>/
                # the end of a tag
                # ?>
                enum.yield :special_close, $&, index, line
                state.pop
              when %r{\A/>}
                # the end of a self-closing tag
                enum.yield :slash_close, $&, index, line
                state.pop
              when %r{\A/}
                # a forward slash
                # /
                enum.yield :slash, $&, index, line
              when /\A=/
                # an equals sign
                # =
                enum.yield :equals, $&, index, line
              when /\A#{NAME}/
                # a name
                # abc
                enum.yield :name, $&, index, line
              when /\A<%/
                # the beginning of an ERB tag
                # <%
                enum.yield :erb_open, $&, index, line
                state << :erb
              when /\A"/
                # the beginning of a string
                enum.yield :string_open, $&, index, line
                state << :string
              else
                raise ParseError,
                      "Unexpected character at #{index}: #{source[index]}"
              end
            end

            index += $&.length
          end

          enum.yield :EOF, nil, index, line
        end
      end

      # If the next token in the list of tokens matches the expected type, then
      # we're going to create a new Token, advance the token enumerator, and
      # return the new Token. Otherwise we're going to raise a
      # MissingTokenError.
      def consume(expected)
        type, value, index, line = tokens.peek

        if expected != type
          raise MissingTokenError, "expected #{expected} got #{type}"
        end

        tokens.next

        Token.new(
          type: type,
          value: value,
          location:
            Location.new(
              start_char: index,
              end_char: index + value.length,
              start_line: line,
              end_line: line + value.count("\n")
            )
        )
      end

      # We're going to yield to the block which should attempt to consume some
      # number of tokens. If any of them are missing, then we're going to return
      # nil from this block.
      def maybe
        yield
      rescue MissingTokenError
      end

      # We're going to attempt to parse everything by yielding to the block. If
      # nothing is returned by the block, then we're going to raise an error.
      # Otherwise we'll return the value returned by the block.
      def atleast
        result = yield
        raise MissingTokenError if result.nil?
        result
      end

      # We're going to attempt to parse with the block many times. We'll stop
      # parsing once we get an error back from the block.
      def many
        items = []

        loop do
          begin
            items << yield
          rescue MissingTokenError
            break
          end
        end

        items
      end

      def parse_until_erb_end
        items = []

        loop do
          begin
            result =
              atleast { maybe { parse_erb_end } || maybe { parse_any_tag } }
            items << result
            break if result.is_a?(ErbEnd)
          rescue ErbKeywordError
            break
          end
        end

        items
      end

      def parse_any_tag_after_erb_elsif
        items = []

        loop do
          result =
            atleast do
              maybe { parse_erb_elsif } || maybe { parse_erb_else } ||
                maybe { parse_erb_end } || maybe { parse_any_tag }
            end
          items << result
          if result.is_a?(ErbElsif) || result.is_a?(ErbElse) ||
               result.is_a?(ErbEnd)
            break
          end
        end

        items
      end

      def parse_any_tag_after_erb_if
        items = []

        loop do
          result =
            atleast do
              maybe { parse_erb_elsif } || maybe { parse_erb_else } ||
                maybe { parse_erb_end } || maybe { parse_any_tag }
            end

          items << result

          if result.is_a?(ErbElsif) || result.is_a?(ErbElse) ||
               result.is_a?(ErbEnd)
            break
          end
        end

        items
      end

      def parse_html_opening_tag
        opening = consume(:open)
        name = consume(:name)
        attributes = many { parse_html_attribute }

        closing =
          atleast do
            maybe { consume(:close) } || maybe { consume(:slash_close) }
          end

        HtmlNode::OpeningTag.new(
          opening: opening,
          name: name,
          attributes: attributes,
          closing: closing,
          location: opening.location.to(closing.location)
        )
      end

      def parse_html_closing_tag
        opening = consume(:slash_open)
        name = consume(:name)
        closing = consume(:close)

        HtmlNode::ClosingTag.new(
          opening: opening,
          name: name,
          closing: closing,
          location: opening.location.to(closing.location)
        )
      end

      def parse_html_element
        opening_tag = parse_html_opening_tag

        if opening_tag.closing.value == ">"
          content = many { parse_any_tag }
          closing_tag = parse_html_closing_tag

          HtmlNode.new(
            opening_tag: opening_tag,
            content: content,
            closing_tag: closing_tag,
            location: opening_tag.location.to(closing_tag.location)
          )
        else
          HtmlNode.new(
            opening_tag: opening_tag,
            content: nil,
            closing_tag: nil,
            location: opening_tag.location
          )
        end
      end

      def parse_erb_if
        opening_tag =
          atleast do
            maybe { consume(:erb_if_open) } ||
              maybe { consume(:erb_unless_open) }
          end

        statement = many { consume(:erb_code) }
        closing_tag = consume(:erb_close)

        contents = maybe { parse_any_tag_after_erb_if } || []

        erb_tag = contents.pop

        unless erb_tag.is_a?(ErbControl) || erb_tag.is_a?(ErbEnd)
          raise(ErbKeywordError, "Found no matching tag to the if-tag")
        end

        if opening_tag.type == :erb_if_open
          ErbIf.new(
            erb_node:
              ErbNode.new(
                opening_tag: opening_tag,
                content: statement.map(&:value).join,
                closing_tag: closing_tag,
                location: opening_tag.location.to(closing_tag.location)
              ),
            elements: contents,
            consequent: erb_tag
          )
        else
          ErbUnless.new(
            erb_node:
              ErbNode.new(
                opening_tag: opening_tag,
                content: statement.map(&:value).join,
                closing_tag: closing_tag,
                location: opening_tag.location.to(closing_tag.location)
              ),
            elements: contents,
            consequent: erb_tag
          )
        end
      end

      def parse_erb_elsif
        opening_tag = consume(:erb_elsif_open)
        statement = many { consume(:erb_code) }
        closing_tag = consume(:erb_close)

        contents = parse_any_tag_after_erb_elsif

        erb_tag = contents.pop

        unless erb_tag.is_a?(ErbControl)
          raise(ErbKeywordError, "Found no matching end-tag to the elsif-tag")
        end

        ErbElsif.new(
          erb_node:
            ErbNode.new(
              opening_tag: opening_tag,
              content: statement.map(&:value).join,
              closing_tag: closing_tag,
              location: opening_tag.location.to(closing_tag.location)
            ),
          elements: contents,
          consequent: erb_tag
        )
      end

      def parse_erb_else
        tag = consume(:erb_else)
        child_nodes = parse_until_erb_end

        erb_end = child_nodes.pop

        unless erb_end.is_a?(ErbEnd)
          raise(ErbKeywordError, "Found no matching end-tag for the else-tag")
        end

        ErbElse.new(erb_node: tag, elements: child_nodes, consequent: erb_end)
      end

      def parse_erb_end
        tag = consume(:erb_end)
        ErbEnd.new(location: tag.location)
      end

      def parse_ruby_or_string(content)
        SyntaxTree.parse(content).statements
      rescue SyntaxTree::Parser::ParseError
        content
      end

      def parse_erb_tag
        opening_tag = consume(:erb_open)
        content = many { consume(:erb_code) }
        closing_tag =
          atleast do
            maybe { consume(:erb_close) } || maybe { parse_erb_do_close }
          end

        erb_node =
          ErbNode.new(
            opening_tag: opening_tag,
            content: content.map(&:value).join,
            closing_tag: closing_tag,
            location: opening_tag.location.to(closing_tag.location)
          )

        if closing_tag.is_a?(ErbDoClose)
          elements = parse_until_erb_end
          erb_end = elements.pop

          unless erb_end.is_a?(ErbEnd)
            raise(ErbKeywordError, "Found no matching end-tag for the do-tag")
          end

          ErbBlock.new(
            erb_node: erb_node,
            elements: elements,
            consequent: erb_end
          )
        else
          erb_node
        end
      end

      def parse_erb_do_close
        token = consume(:erb_do_close)

        ErbDoClose.new(
          location: token.location,
          value: token.value.gsub(/%>/, "")
        )
      end

      def parse_string
        opening = consume(:string_open)
        contents =
          many do
            atleast do
              maybe { consume(:text) } || maybe { consume(:whitespace) } ||
                maybe { parse_erb_tag }
            end
          end
        closing = consume(:string_close)

        ErbString.new(
          opening: opening,
          contents: contents,
          closing: closing,
          location: opening.location.to(closing.location)
        )
      end

      def parse_html_attribute
        key = consume(:name)
        equals = maybe { consume(:equals) }

        if equals.nil?
          HtmlAttribute.new(
            key: key,
            equals: nil,
            value: nil,
            location: key.location
          )
        else
          value = parse_string

          HtmlAttribute.new(
            key: key,
            equals: equals,
            value: value,
            location: key.location.to(value.location)
          )
        end
      end

      def parse_chardata
        values =
          many do
            atleast do
              maybe { consume(:text) } || maybe { consume(:whitespace) }
            end
          end

        token =
          if values.size > 1
            Token.new(
              type: :text,
              value: values.map(&:value).join(""),
              location: values.first.location.to(values.last.location)
            )
          else
            values.first
          end

        CharData.new(value: token, location: token.location) if token
      end
    end
  end
end
