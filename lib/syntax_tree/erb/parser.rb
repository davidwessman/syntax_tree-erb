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

      attr_reader :source, :tokens

      def initialize(source)
        @source = source
        @tokens = make_tokens
      end

      def parse
        doctype = maybe { parse_doctype }
        elements = many { parse_any_tag }

        location =
          elements.first.location.to(elements.last.location) if elements.any?

        Document.new(elements: [doctype].compact + elements, location: location)
      end

      def debug_tokens
        @tokens.each do |key, value, index, line|
          puts("#{key} #{value.inspect} #{index} #{line}")
        end
      end

      private

      def parse_any_tag
        atleast do
          maybe { parse_erb_tag } || maybe { consume(:erb_comment) } ||
            maybe { parse_html_element } || maybe { parse_blank_line } ||
            maybe { parse_chardata }
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
              when /\A\n{2,}/
                # two or more newlines should be ONE blank line
                enum.yield :blank_line, $&, index, line
                line += $&.count("\n")
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
              when /\A<%#.*%>/
                # An ERB-comment
                # <%# this is an ERB comment %>
                enum.yield :erb_comment, $&, index, line
              when /\A<%={1,2}/, /\A<%-/, /\A<%/
                # the beginning of an ERB tag
                # <%
                # <%=, <%==
                enum.yield :erb_open, $&, index, line
                state << :erb_start
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
                enum.yield :string_open_double_quote, $&, index, line
                state << :string
              when /\A[^<]+/
                # plain text content
                # abc
                enum.yield :text, $&, index, line
              else
                raise ParseError,
                      "Unexpected character at #{index}: #{source[index]}"
              end
            in :erb_start
              case source[index..]
              when /\A\s*if/
                # if statement
                enum.yield :erb_if, $&, index, line
                state.pop
                state << :erb
              when /\A\s*unless/
                enum.yield :erb_unless, $&, index, line
                state.pop
                state << :erb
              when /\A\s*elsif/
                enum.yield :erb_elsif, $&, index, line
                state.pop
                state << :erb
              when /\A\s*else/
                enum.yield :erb_else, $&, index, line
                state.pop
                state << :erb
              when /\A\s*case/
                raise(
                  NotImplementedError,
                  "case statements are not implemented"
                )
              when /\A\s*when/
                raise(
                  NotImplementedError,
                  "when statements are not implemented"
                )
              when /\A\s*end/
                enum.yield :erb_end, $&, index, line
                state.pop
                state << :erb
              else
                # If we get here, then we did not have any special
                # keyword in the erb-tag.
                state.pop
                state << :erb
                next
              end
            in :erb
              case source[index..]
              when /\A[\n]+/
                # whitespace
                line += $&.count("\n")
              when /\Ado\b(\s*\|[\w\s,]+\|)?\s*-?%>/
                enum.yield :erb_do_close, $&, index, line
                state.pop
              when /\A-?%>/
                enum.yield :erb_close, $&, index, line
                state.pop
              when /\A\w*\b/
                # Split by word boundary while parsing the code
                # This allows us to separate what_to_do vs do
                enum.yield :erb_code, $&, index, line
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
                enum.yield :string_close_double_quote, $&, index, line
                state.pop
              when /\A<%[=]?/
                # the beginning of an ERB tag
                # <%
                enum.yield :erb_open, $&, index, line
                state << :erb
              when /\A[^<"]+/
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
              when /\A-?%>/
                # the end of an ERB tag
                # -%> or %>
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
                enum.yield :string_open_double_quote, $&, index, line
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

      def parse_until_erb(classes:)
        items = []

        loop do
          result = parse_any_tag
          items << result
          break if classes.any? { |cls| result.is_a?(cls) }
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
          closing_tag = maybe { parse_html_closing_tag }

          if closing_tag.nil?
            raise(
              ParseError,
              "Missing closing tag for <#{opening_tag.name.value}> at #{opening_tag.location}"
            )
          end

          if closing_tag.name.value != opening_tag.name.value
            raise(
              ParseError,
              "Expected closing tag for <#{opening_tag.name.value}> but got <#{closing_tag.name.value}> at #{closing_tag.location}"
            )
          end

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

      def parse_erb_if(erb_node)
        elements =
          maybe { parse_until_erb(classes: [ErbElsif, ErbElse, ErbEnd]) } || []

        erb_tag = elements.pop

        unless erb_tag.is_a?(ErbControl) || erb_tag.is_a?(ErbEnd)
          raise(
            ParseError,
            "Found no matching tag to the if-tag at #{erb_node.location}"
          )
        end

        case erb_node.keyword.type
        when :erb_if
          ErbIf.new(erb_node: erb_node, elements: elements, consequent: erb_tag)
        when :erb_unless
          ErbUnless.new(
            erb_node: erb_node,
            elements: elements,
            consequent: erb_tag
          )
        when :erb_elsif
          ErbElsif.new(
            erb_node: erb_node,
            elements: elements,
            consequent: erb_tag
          )
        end
      end

      def parse_erb_else(erb_node)
        elements = maybe { parse_until_erb(classes: [ErbEnd]) } || []

        erb_end = elements.pop

        unless erb_end.is_a?(ErbEnd)
          raise(
            ParseError,
            "Found no matching end-tag for the else-tag at #{erb_node.location}"
          )
        end

        ErbElse.new(erb_node: erb_node, elements: elements, consequent: erb_end)
      end

      def parse_erb_end(erb_node)
        ErbEnd.new(
          opening_tag: erb_node.opening_tag,
          keyword: erb_node.keyword,
          content: nil,
          closing_tag: erb_node.closing_tag,
          location: erb_node.location
        )
      end

      def parse_ruby_or_string(content)
        SyntaxTree.parse(content).statements
      rescue SyntaxTree::Parser::ParseError
        content
      end

      def parse_erb_tag
        opening_tag = consume(:erb_open)
        keyword =
          maybe { consume(:erb_if) } || maybe { consume(:erb_unless) } ||
            maybe { consume(:erb_elsif) } || maybe { consume(:erb_else) } ||
            maybe { consume(:erb_end) }

        content = parse_until_erb_close
        closing_tag = content.pop

        if !closing_tag.is_a?(ErbClose)
          raise(
            ParseError,
            "Found no matching closing tag for the erb-tag at #{opening_tag.location}"
          )
        end

        erb_node =
          ErbNode.new(
            opening_tag: opening_tag,
            keyword: keyword,
            content: content,
            closing_tag: closing_tag,
            location: opening_tag.location.to(closing_tag.location)
          )

        case keyword&.type
        when :erb_if, :erb_unless, :erb_elsif
          parse_erb_if(erb_node)
        when :erb_else
          parse_erb_else(erb_node)
        when :erb_end
          parse_erb_end(erb_node)
        else
          if closing_tag.is_a?(ErbDoClose)
            elements = maybe { parse_until_erb(classes: [ErbEnd]) } || []
            erb_end = elements.pop

            unless erb_end.is_a?(ErbEnd)
              raise(
                ParseError,
                "Found no matching end-tag for the do-tag at #{erb_node.location}"
              )
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
      end

      def parse_until_erb_close
        items = []

        loop do
          result =
            maybe { parse_erb_do_close } || maybe { parse_erb_close } ||
              maybe { consume(:erb_code) }
          items << result

          break if result.is_a?(ErbClose)
        end

        items
      end

      def parse_blank_line
        blank_line = consume(:blank_line)

        CharData.new(value: blank_line, location: blank_line.location)
      end

      def parse_erb_close
        closing = consume(:erb_close)

        ErbClose.new(location: closing.location, closing: closing)
      end

      def parse_erb_do_close
        closing = consume(:erb_do_close)

        ErbDoClose.new(location: closing.location, closing: closing)
      end

      def parse_html_string
        opening =
          atleast do
            maybe { consume(:string_open_double_quote) } ||
              maybe { consume(:string_open_single_quote) }
          end
        contents =
          many do
            atleast do
              maybe { consume(:text) } || maybe { consume(:whitespace) } ||
                maybe { parse_erb_tag }
            end
          end

        closing =
          if opening.type == :string_open_double_quote
            consume(:string_close_double_quote)
          else
            consume(:string_close_single_quote)
          end

        HtmlString.new(
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
          value = parse_html_string

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

      def parse_doctype
        opening = consume(:doctype)
        name = consume(:name)
        closing = consume(:close)

        DocType.new(
          opening: opening,
          name: name,
          closing: closing,
          location: opening.location.to(closing.location)
        )
      end
    end
  end
end
