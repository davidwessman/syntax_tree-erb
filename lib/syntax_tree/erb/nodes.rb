# frozen_string_literal: true

module SyntaxTree
  module ERB
    # A Location represents a position for a node in the source file.
    class Location
      attr_reader :start_char, :end_char, :start_line, :end_line

      def initialize(start_char:, end_char:, start_line:, end_line:)
        @start_char = start_char
        @end_char = end_char
        @start_line = start_line
        @end_line = end_line
      end

      def deconstruct_keys(keys)
        {
          start_char: start_char,
          end_char: end_char,
          start_line: start_line,
          end_line: end_line
        }
      end

      def to(other)
        Location.new(
          start_char: start_char,
          start_line: start_line,
          end_char: other.end_char,
          end_line: other.end_line
        )
      end

      def <=>(other)
        start_char <=> other.start_char
      end

      def to_s
        if start_line == end_line
          "line #{start_line}, char #{start_char}..#{end_char}"
        else
          "line #{start_line},char #{start_char} to line #{end_line}, char #{end_char}"
        end
      end
    end

    # A parent node that contains a bit of shared functionality.
    class Node
      def format(q)
        Format.new(q).visit(self)
      end

      def pretty_print(q)
        PrettyPrint.new(q).visit(self)
      end

      def without_new_line
        self
      end

      def skip?
        false
      end
    end

    # A Token is any kind of lexical token from the source. It has a type, a
    # value which is a subset of the source, and an index where it starts in
    # the source.
    class Token < Node
      attr_reader :type, :value, :location

      def initialize(type:, value:, location:)
        @type = type
        @value = value
        @location = location
      end

      def accept(visitor)
        visitor.visit_token(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { type: type, value: value, location: location }
      end
    end

    # The Document node is the top of the syntax tree.
    # It contains any number of:
    # - Text
    # - HtmlNode
    # - ErbNodes
    class Document < Node
      attr_reader :elements, :location

      def initialize(elements:, location:)
        @elements = elements
        @location = location
      end

      def accept(visitor)
        visitor.visit_document(self)
      end

      def child_nodes
        [*elements].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { elements: elements, location: location }
      end
    end

    # This is a base class for a Node that can also hold an appended
    # new line.
    class Element < Node
      attr_reader(:new_line, :location)

      def initialize(new_line:, location:)
        @new_line = new_line
        @location = location
      end

      def without_new_line
        self.class.new(**deconstruct_keys([]).merge(new_line: nil))
      end

      def deconstruct_keys(keys)
        { new_line: new_line, location: location }
      end
    end

    # This is a base class for a block that contains:
    # - an opening
    # - optional elements
    # - optional closing
    class Block < Node
      attr_reader(:opening, :elements, :closing, :location)
      def initialize(opening:, location:, elements: nil, closing: nil)
        @opening = opening
        @elements = elements || []
        @closing = closing
        @location = location
      end

      def accept(visitor)
        visitor.visit_block(self)
      end

      def child_nodes
        [opening, *elements, closing].compact
      end

      def new_line
        closing.new_line if closing.respond_to?(:new_line)
      end

      def without_new_line
        self.class.new(
          **deconstruct_keys([]).merge(closing: closing&.without_new_line)
        )
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening: opening,
          elements: elements,
          closing: closing,
          location: location
        }
      end
    end

    # An element is a child of the document. It contains an opening tag, any
    # optional content within the tag, and a closing tag. It can also
    # potentially contain an opening tag that self-closes, in which case the
    # content and closing tag will be nil.
    class HtmlNode < Block
      # These elements do not require a closing tag
      # https://developer.mozilla.org/en-US/docs/Glossary/Void_element
      HTML_VOID_ELEMENTS = %w[
        area
        base
        br
        col
        embed
        hr
        img
        input
        link
        meta
        param
        source
        track
        wbr
      ]

      # The opening tag of an element. It contains the opening character (<),
      # the name of the element, any optional attributes, and the closing
      # token (either > or />).
      class OpeningTag < Element
        attr_reader :opening, :name, :attributes, :closing

        def initialize(
          opening:,
          name:,
          attributes:,
          closing:,
          new_line:,
          location:
        )
          super(new_line: new_line, location: location)
          @opening = opening
          @name = name
          @attributes = attributes
          @closing = closing
        end

        def accept(visitor)
          visitor.visit_opening_tag(self)
        end

        def child_nodes
          [opening, name, *attributes, closing]
        end

        def is_void_element?
          HTML_VOID_ELEMENTS.include?(name.value)
        end

        alias deconstruct child_nodes

        def deconstruct_keys(keys)
          super.merge(
            opening: opening,
            name: name,
            attributes: attributes,
            closing: closing
          )
        end
      end

      # The closing tag of an element. It contains the opening character (<),
      # the name of the element, and the closing character (>).
      class ClosingTag < Element
        attr_reader :opening, :name, :closing

        def initialize(opening:, name:, closing:, location:, new_line:)
          super(new_line: new_line, location: location)
          @opening = opening
          @name = name
          @closing = closing
        end

        def accept(visitor)
          visitor.visit_closing_tag(self)
        end

        def child_nodes
          [opening, name, closing]
        end

        alias deconstruct child_nodes

        def deconstruct_keys(keys)
          super.merge(opening: opening, name: name, closing: closing)
        end
      end

      def is_void_element?
        false
      end

      def without_new_line
        self.class.new(
          **deconstruct_keys([]).merge(
            opening: closing.nil? ? opening.without_new_line : opening,
            closing: closing&.without_new_line
          )
        )
      end

      # The HTML-closing tag is responsible for new lines after the node.
      def new_line
        closing.nil? ? opening.new_line : closing&.new_line
      end

      def accept(visitor)
        visitor.visit_html(self)
      end
    end

    class ErbNode < Element
      attr_reader :opening_tag, :keyword, :content, :closing_tag

      def initialize(
        opening_tag:,
        keyword:,
        content:,
        closing_tag:,
        new_line:,
        location:
      )
        super(new_line: new_line, location: location)
        @opening_tag = opening_tag
        # prune whitespace from keyword
        @keyword =
          if keyword
            Token.new(
              type: keyword.type,
              value: keyword.value.strip,
              location: keyword.location
            )
          end

        @content = prepare_content(content)
        @closing_tag = closing_tag
      end

      def accept(visitor)
        visitor.visit_erb(self)
      end

      def child_nodes
        [opening_tag, keyword, content, closing_tag].compact
      end

      def new_line
        closing_tag&.new_line
      end

      def without_new_line
        self.class.new(
          **deconstruct_keys([]).merge(
            closing_tag: closing_tag.without_new_line
          )
        )
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        super.merge(
          opening_tag: opening_tag,
          keyword: keyword,
          content: content,
          closing_tag: closing_tag
        )
      end

      private

      def prepare_content(content)
        if content.is_a?(ErbContent)
          content
        else
          # Set content to nil if it is empty
          content ||= []

          ErbContent.new(value: content)
        end
      rescue SyntaxTree::Parser::ParseError
        # Try to add the keyword to see if it parses
        result = ErbContent.new(value: [keyword, *content])
        @keyword = nil

        result
      end
    end

    class ErbBlock < Block
      def initialize(opening:, location:, elements: nil, closing: nil)
        super(
          opening: opening,
          location: location,
          elements: elements,
          closing: closing
        )
      end

      def accept(visitor)
        visitor.visit_erb_block(self)
      end
    end

    class ErbClose < Element
      attr_reader :closing

      def initialize(closing:, new_line:, location:)
        super(new_line: new_line, location: location)
        @closing = closing
      end

      def accept(visitor)
        visitor.visit_erb_close(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        super.merge(closing: closing)
      end
    end

    class ErbDoClose < ErbClose
      def accept(visitor)
        visitor.visit_erb_do_close(self)
      end
    end

    class ErbControl < Block
    end

    class ErbIf < ErbControl
      # opening: ErbNode
      # elements: [[HtmlNode | ErbNode | CharDataNode]]
      # closing: [nil | ErbElsif | ErbElse]
      def accept(visitor)
        visitor.visit_erb_if(self)
      end
    end

    class ErbUnless < ErbIf
      # opening: ErbNode
      # elements: [[HtmlNode | ErbNode | CharDataNode]]
      # closing: [nil | ErbElsif | ErbElse]
      def accept(visitor)
        visitor.visit_erb_if(self)
      end
    end

    class ErbElsif < ErbIf
      def accept(visitor)
        visitor.visit_erb_if(self)
      end
    end

    class ErbElse < ErbIf
      def accept(visitor)
        visitor.visit_erb_else(self)
      end
    end

    class ErbEnd < ErbNode
      def accept(visitor)
        visitor.visit_erb_end(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes
    end

    class ErbCase < ErbControl
      # opening: ErbNode
      # elements: [[HtmlNode | ErbNode | CharDataNode]]
      # closing: [nil | ErbCaseWhen | ErbElse | ErbEnd]
      def accept(visitor)
        visitor.visit_erb_case(self)
      end
    end

    class ErbCaseWhen < ErbControl
      # opening: ErbNode
      # elements: [[HtmlNode | ErbNode | CharDataNode]]
      # closing: [nil | ErbCaseWhen | ErbElse | ErbEnd]
      def accept(visitor)
        visitor.visit_erb_case_when(self)
      end
    end

    class ErbContent < Node
      attr_reader(:value)

      def initialize(value:)
        if value.is_a?(Array)
          value =
            value
              .map do |token|
                if token.is_a?(Token)
                  token.value
                elsif token.is_a?(ErbYield)
                  ErbYield::PLACEHOLDER
                else
                  token
                end
              end
              .join
        end
        @value = SyntaxTree.parse(value.strip)
      end

      def blank?
        value.nil? ||
          value
            .statements
            .child_nodes
            .reject { |node| node.is_a?(SyntaxTree::VoidStmt) }
            .empty?
      end

      def accept(visitor)
        visitor.visit_erb_content(self)
      end

      def child_nodes
        [@value].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { value: value }
      end
    end

    class ErbYield < Element
      PLACEHOLDER = "qqqqy"
      def initialize(new_line:, location:)
        super(new_line: new_line, location: location)
      end

      def accept(visitor)
        visitor.visit_erb_yield(self)
      end

      def child_nodes
        []
      end
    end

    # An HtmlAttribute is a key-value pair within a tag. It contains the key, the
    # equals sign, and the value.
    class HtmlAttribute < Node
      attr_reader :key, :equals, :value, :location

      def initialize(key:, equals:, value:, location:)
        @key = key
        @equals = equals
        @value = value
        @location = location
      end

      def accept(visitor)
        visitor.visit_attribute(self)
      end

      def child_nodes
        [key, equals, value]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { key: key, equals: equals, value: value, location: location }
      end
    end

    # A HtmlString can include ERB-tags
    class HtmlString < Node
      attr_reader :opening, :contents, :closing, :location

      def initialize(opening:, contents:, closing:, location:)
        @opening = opening
        @contents = contents
        @closing = closing
        @location = location
      end

      def accept(visitor)
        visitor.visit_html_string(self)
      end

      def child_nodes
        [*contents]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening: opening,
          contents: contents,
          closing: closing,
          location: location
        }
      end
    end

    class HtmlComment < Element
      attr_reader :token

      def initialize(token:, new_line:, location:)
        super(new_line: new_line, location: location)
        @token = token
      end

      def accept(visitor)
        visitor.visit_html_comment(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        super.merge(token: token)
      end
    end

    class ErbComment < Element
      attr_reader :token

      def initialize(token:, new_line:, location:)
        super(new_line: new_line, location: location)
        @token = token
      end

      def accept(visitor)
        visitor.visit_erb_comment(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        super.merge(token: token)
      end
    end

    # A CharData contains either plain text or whitespace within an element.
    # It wraps a single token value.
    class CharData < Element
      attr_reader :value

      def initialize(value:, new_line:, location:)
        super(new_line: new_line, location: location)
        @value = value
      end

      def accept(visitor)
        visitor.visit_char_data(self)
      end

      def child_nodes
        [value]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        super.merge(value: value)
      end

      def skip?
        value.value.strip.empty?
      end

      # Also remove trailing whitespace
      def without_new_line
        self.class.new(
          **deconstruct_keys([]).merge(
            new_line: nil,
            value:
              Token.new(
                type: value.type,
                location: value.location,
                value: value.value.rstrip
              )
          )
        )
      end
    end

    class NewLine < Node
      attr_reader :count, :location

      def initialize(location:, count:)
        @location = location
        @count = count
      end

      def accept(visitor)
        visitor.visit_new_line(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { location: location, count: count }
      end
    end

    # A document type declaration is a special kind of tag that specifies the
    # type of the document. It contains an opening declaration, the name of
    # the document type, an optional external identifier, and a closing of the
    # tag.
    class Doctype < Element
      attr_reader :opening, :name, :closing

      def initialize(opening:, name:, closing:, new_line:, location:)
        super(new_line: new_line, location: location)
        @opening = opening
        @name = name
        @closing = closing
      end

      def accept(visitor)
        visitor.visit_doctype(self)
      end

      def child_nodes
        [opening, name, closing].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        super.merge(opening: opening, name: name, closing: closing)
      end
    end
  end
end
