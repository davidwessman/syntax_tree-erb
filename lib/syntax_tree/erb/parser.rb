# frozen_string_literal: true

module SyntaxTree
  module ERB
    class Parser
      # This is the parent class of any kind of errors that will be raised by
      # the parser.

      # This error occurs when a certain token is expected in a certain place
      # but is not found. Sometimes this is handled internally because some
      # elements are optional. Other times it is not and it is raised to end the
      # parsing process.
      class MissingTokenError < SyntaxTree::Parser::ParseError
      end

      attr_reader :source, :tokens

      def initialize(source)
        @source = source
        @tokens = make_tokens
        @found_doctype = false
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
        loop do
          tag =
            atleast do
              maybe { parse_doctype } || maybe { parse_html_comment } ||
                maybe { parse_erb_tag } || maybe { parse_erb_comment } ||
                maybe { parse_html_element } || maybe { parse_new_line } ||
                maybe { parse_chardata }
            end

          if tag.is_a?(Doctype)
            if @found_doctype
              raise(
                SyntaxTree::Parser::ParseError.new(
                  "Duplicate doctype declaration",
                  tag.location.start_line,
                  tag.location.start_column
                )
              )
            else
              @found_doctype = true
            end
          end

          # Ignore new lines in beginning of document
          next if tag.is_a?(NewLine)

          # Allow skipping empty CharData
          return tag unless tag.skip?
        end
      end

      def make_tokens
        Enumerator.new do |enum|
          index = 0
          column_index = 0
          line = 1
          state = %i[outside]

          while index < source.length
            case state.last
            in :outside
              case source[index..]
              when /\A\n{2,}/
                # two or more newlines should be ONE blank line
                enum.yield(:blank_line, $&, index, line, column_index)
                line += $&.count("\n")
              when /\A\n/
                # newlines
                enum.yield(:new_line, $&, index, line, column_index)
                line += 1
              when /\A<!--(.|\r?\n)*?-->/m
                # comments
                # <!-- this is a comment -->
                enum.yield(:html_comment, $&, index, line, column_index)
                line += $&.count("\n")
              when /\A<!DOCTYPE/, /\A<!doctype/
                # document type tags
                # <!DOCTYPE
                enum.yield(:doctype, $&, index, line, column_index)
                state << :inside
              when /\A<%#[\s\S]*?%>/
                # An ERB-comment
                # <%# this is an ERB comment %>
                enum.yield(:erb_comment, $&, index, line, column_index)
              when /\A<%={1,2}/, /\A<%-/, /\A<%/
                # the beginning of an ERB tag
                # <%
                # <%=, <%==
                enum.yield(:erb_open, $&, index, line, column_index)
                state << :erb_start
                line += $&.count("\n")
              when %r{\A</}
                # the beginning of a closing tag
                # </
                enum.yield(:slash_open, $&, index, line, column_index)
                state << :inside
              when /\A</
                # the beginning of an opening tag
                # <
                enum.yield(:open, $&, index, line, column_index)
                state << :inside
              when /\A(?: |\t|\r)+/m
                # whitespace
                enum.yield(:whitespace, $&, index, line, column_index)
              when /\A(?!\s+$)[^<\n]+/
                # plain text content, but do not allow only white space
                # abc
                enum.yield(:text, $&, index, line, column_index)
              else
                raise(
                  SyntaxTree::Parser::ParseError.new(
                    "Unexpected character: #{source[index]}",
                    line,
                    column_index
                  )
                )
              end
            in :erb_start
              case source[index..]
              when /\A\s*if/
                # if statement
                enum.yield(:erb_if, $&, index, line, column_index)
                state.pop
                state << :erb
              when /\A\s*unless/
                enum.yield(:erb_unless, $&, index, line, column_index)
                state.pop
                state << :erb
              when /\A\s*elsif/
                enum.yield(:erb_elsif, $&, index, line, column_index)
                state.pop
                state << :erb
              when /\A\s*else/
                enum.yield(:erb_else, $&, index, line, column_index)
                state.pop
                state << :erb
              when /\A\s*case/
                enum.yield(:erb_case, $&, index, line, column_index)
                state.pop
                state << :erb
              when /\A\s*when/
                enum.yield(:erb_when, $&, index, line, column_index)
                state.pop
                state << :erb
              when /\A\s*end/
                enum.yield(:erb_end, $&, index, line, column_index)
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
                # newlines
                enum.yield(:erb_code, $&, index, line, column_index)
                line += $&.count("\n")
              when /\Ado\b(\s*\|[\w\s,]+\|)?\s*-?%>/
                enum.yield(:erb_do_close, $&, index, line, column_index)
                state.pop
              when /\A-?%>/
                enum.yield(:erb_close, $&, index, line, column_index)
                state.pop
              when /\Ayield\b/
                enum.yield(:erb_yield, $&, index, line, column_index)
              when /\A[\p{L}\w]*\b/
                # Split by word boundary while parsing the code
                # This allows us to separate what_to_do vs do
                enum.yield(:erb_code, $&, index, line, column_index)
              else
                enum.yield(:erb_code, source[index], index, line, column_index)
                index += 1
                column_index += 1
                next
              end
            in :string_single_quote
              case source[index..]
              when /\A(?: |\t|\n|\r\n)+/m
                enum.yield(:whitespace, $&, index, line, column_index)
                line += $&.count("\n")
              when /\A\'/
                # the end of a quoted string
                enum.yield(
                  :string_close_single_quote,
                  $&,
                  index,
                  line,
                  column_index
                )
                state.pop
              when /\A<%[=]?/
                # the beginning of an ERB tag
                # <%
                enum.yield(:erb_open, $&, index, line, column_index)
                state << :erb_start
              when /\A[^<']+/
                # plain text content
                # abc
                enum.yield(:text, $&, index, line, column_index)
              else
                raise(
                  SyntaxTree::Parser::ParseError.new(
                    "Unexpected character, #{source[index]}, when looking for closing single quote",
                    line,
                    column_index
                  )
                )
              end
            in :string_double_quote
              case source[index..]
              when /\A(?: |\t|\n|\r\n)+/m
                enum.yield(:whitespace, $&, index, line, column_index)
                line += $&.count("\n")
              when /\A\"/
                enum.yield(
                  :string_close_double_quote,
                  $&,
                  index,
                  line,
                  column_index
                )
                state.pop
              when /\A<%[=]?/
                # the beginning of an ERB tag
                # <%
                enum.yield(:erb_open, $&, index, line, column_index)
                state << :erb_start
              when /\A[^<"]+/
                # plain text content
                # abc
                enum.yield(:text, $&, index, line, column_index)
              else
                raise(
                  SyntaxTree::Parser::ParseError.new(
                    "Unexpected character, #{source[index]}, when looking for closing double quote",
                    line,
                    column_index
                  )
                )
              end
            in :inside
              case source[index..]
              when /\A[ \t\r\n]+/
                # whitespace
                line += $&.count("\n")
              when /\A-?%>/
                # the end of an ERB tag
                # -%> or %>
                enum.yield(:erb_close, $&, index, line, column_index)
                state.pop
              when /\A>/
                # the end of a tag
                # >
                enum.yield(:close, $&, index, line, column_index)
                state.pop
              when /\A\?>/
                # the end of a tag
                # ?>
                enum.yield(:special_close, $&, index, line, column_index)
                state.pop
              when %r{\A/>}
                # the end of a self-closing tag
                enum.yield(:slash_close, $&, index, line, column_index)
                state.pop
              when %r{\A/}
                # a forward slash
                # /
                enum.yield :slash, $&, index, line, column_index
              when /\A=/
                # an equals sign
                # =
                enum.yield :equals, $&, index, line, column_index
              when /\A[@#]*[:\w\.\-\_]+\b/
                # a name for an element or an attribute
                # strong, vue-component-kebab, VueComponentPascal
                # abc, #abc, @abc, :abc
                enum.yield :name, $&, index, line, column_index
              when /\A<%/
                # the beginning of an ERB tag
                # <%
                enum.yield :erb_open, $&, index, line, column_index
                state << :erb_start
              when /\A"/
                # the beginning of a string
                enum.yield(
                  :string_open_double_quote,
                  $&,
                  index,
                  line,
                  column_index
                )
                state << :string_double_quote
              when /\A'/
                # the beginning of a string
                enum.yield(
                  :string_open_single_quote,
                  $&,
                  index,
                  line,
                  column_index
                )
                state << :string_single_quote
              else
                raise(
                  SyntaxTree::Parser::ParseError.new(
                    "Unexpected character, #{source[index]}, when parsing HTML- or ERB-tag",
                    line,
                    column_index
                  )
                )
              end
            end

            index += $&.length
            column_index = $&.rindex("\n") || column_index + $&.length
          end

          enum.yield(:EOF, nil, index, line, column_index)
        end
      end

      # If the next token in the list of tokens matches the expected type, then
      # we're going to create a new Token, advance the token enumerator, and
      # return the new Token. Otherwise we're going to raise a
      # MissingTokenError.
      def consume(expected)
        type, value, index, line, column = tokens.peek

        if expected != type
          raise(
            MissingTokenError.new(
              "expected #{expected} got #{type}",
              line,
              index
            )
          )
        end

        tokens.next

        rindex = value.rindex("\n")

        Token.new(
          type: type,
          value: value,
          location:
            Location.new(
              start_char: index,
              end_char: index + value.length,
              start_line: line,
              end_line: line + value.count("\n"),
              start_column: column,
              end_column: rindex ? value.length - rindex : column + value.length
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
        if result.nil?
          raise(MissingTokenError.new("No matching token", nil, nil))
        end
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

        if name.value =~ /\A[@:#]/
          raise(
            SyntaxTree::Parser::ParseError.new(
              "Invalid HTML-tag name #{name.value}",
              name.location.start_line,
              name.location.start_column
            )
          )
        end

        attributes =
          many do
            atleast do
              maybe { parse_erb_tag } || maybe { parse_html_attribute }
            end
          end

        closing =
          atleast do
            maybe { consume(:close) } || maybe { consume(:slash_close) }
          end

        new_line = maybe { parse_new_line }

        # Parse any whitespace after new lines
        maybe { consume(:whitespace) }

        HtmlNode::OpeningTag.new(
          opening: opening,
          name: name,
          attributes: attributes,
          closing: closing,
          location: opening.location.to(closing.location),
          new_line: new_line
        )
      end

      def parse_html_closing
        opening = consume(:slash_open)
        name = consume(:name)
        closing = consume(:close)

        new_line = maybe { parse_new_line }

        HtmlNode::ClosingTag.new(
          opening: opening,
          name: name,
          closing: closing,
          location: opening.location.to(closing.location),
          new_line: new_line
        )
      end

      def parse_html_element
        opening = parse_html_opening_tag

        if opening.closing.value == "/>"
          HtmlNode.new(opening: opening, location: opening.location)
        elsif opening.is_void_element?
          HtmlNode.new(opening: opening, location: opening.location)
        else
          elements = many { parse_any_tag }
          closing = maybe { parse_html_closing }

          if closing.nil?
            raise(
              SyntaxTree::Parser::ParseError.new(
                "Missing closing tag for <#{opening.name.value}>",
                opening.location.start_line,
                opening.location.start_column
              )
            )
          end

          if closing.name.value != opening.name.value
            raise(
              SyntaxTree::Parser::ParseError.new(
                "Expected closing tag for <#{opening.name.value}> but got <#{closing.name.value}>",
                closing.location.start_line,
                closing.location.start_column
              )
            )
          end

          HtmlNode.new(
            opening: opening,
            elements: elements,
            closing: closing,
            location: opening.location.to(closing.location)
          )
        end
      end

      def parse_erb_case(erb_node)
        elements =
          maybe { parse_until_erb(classes: [ErbCaseWhen, ErbElse, ErbEnd]) } ||
            []

        erb_tag = elements.pop

        unless erb_tag.is_a?(ErbCaseWhen) || erb_tag.is_a?(ErbElse) ||
                 erb_tag.is_a?(ErbEnd)
          location = erb_tag&.location || erb_node.location
          raise(
            SyntaxTree::Parser::ParseError.new(
              "No matching ERB-tag for the <% #{erb_node.keyword.value} %>",
              location.start_line,
              location.start_column
            )
          )
        end

        case erb_node.keyword.type
        when :erb_case
          ErbCase.new(
            opening: erb_node,
            elements: elements,
            closing: erb_tag,
            location: erb_node.location.to(erb_tag.location)
          )
        when :erb_when
          ErbCaseWhen.new(
            opening: erb_node,
            elements: elements,
            closing: erb_tag,
            location: erb_node.location.to(erb_tag.location)
          )
        else
          raise(
            SyntaxTree::Parser::ParseError.new(
              "No matching when- or else-tag for the case-tag",
              erb_node.location.start_line,
              erb_node.location.start_column
            )
          )
        end
      end

      def parse_erb_if(erb_node)
        # Skip any leading whitespace
        maybe { consume(:whitespace) }

        elements =
          maybe { parse_until_erb(classes: [ErbElsif, ErbElse, ErbEnd]) } || []

        erb_tag = elements.pop

        unless erb_tag.is_a?(ErbControl) || erb_tag.is_a?(ErbEnd)
          raise(
            SyntaxTree::Parser::ParseError.new(
              "No matching ERB-tag for the <% if %>",
              erb_node.location.start_line,
              erb_node.location.start_column
            )
          )
        end

        case erb_node.keyword.type
        when :erb_if
          ErbIf.new(
            opening: erb_node,
            elements: elements,
            closing: erb_tag,
            location: erb_node.location.to(erb_tag.location)
          )
        when :erb_unless
          ErbUnless.new(
            opening: erb_node,
            elements: elements,
            closing: erb_tag,
            location: erb_node.location.to(erb_tag.location)
          )
        when :erb_elsif
          ErbElsif.new(
            opening: erb_node,
            elements: elements,
            closing: erb_tag,
            location: erb_node.location.to(erb_tag.location)
          )
        else
          raise(
            SyntaxTree::Parser::ParseError.new(
              "No matching <% elsif %> or <% else %> for the <% if %>",
              erb_node.location.start_line,
              erb_node.location.start_column
            )
          )
        end
      end

      def parse_erb_else(erb_node)
        elements = maybe { parse_until_erb(classes: [ErbEnd]) } || []

        erb_end = elements.pop

        unless erb_end.is_a?(ErbEnd)
          raise(
            SyntaxTree::Parser::ParseError.new(
              "No matching <% end %> for the <% else %>",
              erb_node.location.start_line,
              erb_node.location.start_column
            )
          )
        end

        ErbElse.new(
          opening: erb_node,
          elements: elements,
          closing: erb_end,
          location: erb_node.location.to(erb_end.location)
        )
      end

      def parse_erb_end(erb_node)
        new_line = maybe { parse_new_line }

        ErbEnd.new(
          opening_tag: erb_node.opening_tag,
          keyword: erb_node.keyword,
          content: nil,
          closing_tag: erb_node.closing_tag,
          new_line: new_line,
          location: erb_node.location
        )
      end

      def parse_erb_tag
        opening_tag = consume(:erb_open)
        keyword =
          maybe { consume(:erb_if) } || maybe { consume(:erb_unless) } ||
            maybe { consume(:erb_elsif) } || maybe { consume(:erb_else) } ||
            maybe { consume(:erb_end) } || maybe { consume(:erb_case) } ||
            maybe { consume(:erb_when) }

        content = parse_until_erb_close
        closing_tag = content.pop

        if !closing_tag.is_a?(ErbClose)
          raise(
            SyntaxTree::Parser::ParseError.new(
              "No matching closing tag for the <% #{keyword.value} %>",
              closing_tag.location.start_line,
              closing_tag.location.start_column
            )
          )
        end

        new_line = maybe { parse_new_line }

        erb_node =
          ErbNode.new(
            opening_tag: opening_tag,
            keyword: keyword,
            content: content,
            closing_tag: closing_tag,
            new_line: new_line,
            location: opening_tag.location.to(closing_tag.location)
          )

        case erb_node.keyword&.type
        when :erb_if, :erb_unless, :erb_elsif
          parse_erb_if(erb_node)
        when :erb_case, :erb_when
          parse_erb_case(erb_node)
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
                SyntaxTree::Parser::ParseError.new(
                  "No matching <% end %> for the <% do %>",
                  erb_node.location.start_line,
                  erb_node.location.start_column
                )
              )
            end

            ErbBlock.new(
              opening: erb_node,
              elements: elements,
              closing: erb_end,
              location: erb_node.location.to(erb_end.location)
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
            atleast do
              maybe { parse_erb_do_close } || maybe { parse_erb_close } ||
                maybe { parse_erb_yield } || maybe { consume(:erb_code) }
            end

          items << result

          break if result.is_a?(ErbClose)
        end

        items
      end

      # This method is called at the end of most tags, it fixes:
      # 1. Parsing any new lines after the tag
      # 2. Parsing any whitespace after the new lines
      # The whitespace is just consumed
      def parse_new_line
        line_break =
          atleast do
            maybe { consume(:blank_line) } || maybe { consume(:new_line) }
          end

        maybe { consume(:whitespace) }

        NewLine.new(
          location: line_break.location,
          count: line_break.value.count("\n")
        )
      end

      def parse_erb_close
        closing = consume(:erb_close)

        new_line = maybe { parse_new_line }

        ErbClose.new(
          location: closing.location,
          new_line: new_line,
          closing: closing
        )
      end

      def parse_erb_do_close
        closing = consume(:erb_do_close)

        new_line = maybe { parse_new_line }

        ErbDoClose.new(
          location: closing.location,
          new_line: new_line,
          closing: closing
        )
      end

      def parse_erb_yield
        token = consume(:erb_yield)

        new_line = maybe { parse_new_line }

        ErbYield.new(location: token.location, new_line: new_line)
      end

      def parse_html_string
        opening =
          maybe { consume(:string_open_double_quote) } ||
            maybe { consume(:string_open_single_quote) }

        if opening.nil?
          value = consume(:name)

          return(
            HtmlString.new(
              opening: nil,
              contents: [value],
              closing: nil,
              location: value.location
            )
          )
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
              maybe { consume(:string_open_double_quote) } ||
                maybe { consume(:string_open_single_quote) } ||
                maybe { consume(:string_close_double_quote) } ||
                maybe { consume(:string_close_single_quote) } ||
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

        new_line = maybe { parse_new_line }

        if token&.value
          CharData.new(
            value: token,
            location: token.location,
            new_line: new_line
          )
        end
      end

      def parse_doctype
        opening = consume(:doctype)
        name = consume(:name)
        closing = consume(:close)

        new_line = maybe { parse_new_line }

        Doctype.new(
          opening: opening,
          name: name,
          closing: closing,
          new_line: new_line,
          location: opening.location.to(closing.location)
        )
      end

      def parse_html_comment
        comment = consume(:html_comment)

        new_line = maybe { parse_new_line }

        HtmlComment.new(
          token: comment,
          new_line: new_line,
          location: comment.location
        )
      end

      def parse_erb_comment
        comment = consume(:erb_comment)

        new_line = maybe { parse_new_line }

        ErbComment.new(
          token: comment,
          new_line: new_line,
          location: comment.location
        )
      end
    end
  end
end
