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

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening: opening,
          content: content,
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
      # The opening tag of an element. It contains the opening character (<),
      # the name of the element, any optional attributes, and the closing
      # token (either > or />).
      class OpeningTag < Node
        attr_reader :opening, :name, :attributes, :closing, :location

        def initialize(opening:, name:, attributes:, closing:, location:)
          @opening = opening
          @name = name
          @attributes = attributes
          @closing = closing
          @location = location
        end

        def accept(visitor)
          visitor.visit_opening_tag(self)
        end

        def child_nodes
          [opening, name, *attributes, closing]
        end

        alias deconstruct child_nodes

        def deconstruct_keys(keys)
          {
            opening: opening,
            name: name,
            attributes: attributes,
            closing: closing,
            location: location
          }
        end
      end

      # The closing tag of an element. It contains the opening character (<),
      # the name of the element, and the closing character (>).
      class ClosingTag < Node
        attr_reader :opening, :name, :closing, :location

        def initialize(opening:, name:, closing:, location:)
          @opening = opening
          @name = name
          @closing = closing
          @location = location
        end

        def accept(visitor)
          visitor.visit_closing_tag(self)
        end

        def child_nodes
          [opening, name, closing]
        end

        alias deconstruct child_nodes

        def deconstruct_keys(keys)
          { opening: opening, name: name, closing: closing, location: location }
        end
      end

      def accept(visitor)
        visitor.visit_html(self)
      end
    end

    class ErbNode < Node
      attr_reader :opening_tag, :keyword, :content, :closing_tag, :location

      def initialize(opening_tag:, keyword:, content:, closing_tag:, location:)
        @opening_tag = opening_tag
        @keyword = keyword
        @content = ErbContent.new(value: content.map(&:value).join) if content
        @closing_tag = closing_tag
        @location = location
      end

      def accept(visitor)
        visitor.visit_erb(self)
      end

      def child_nodes
        [opening_tag, keyword, content, closing_tag].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening_tag: opening_tag,
          keyword: keyword,
          content: content,
          closing_tag: closing_tag,
          location: location
        }
      end
    end

    class ErbBlock < Block
      def accept(visitor)
        visitor.visit_erb_block(self)
      end
    end

    class ErbClose < Node
      attr_reader :location, :closing

      def initialize(location:, closing:)
        @location = location
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
        { location: location, closing: closing }
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
        visitor.visit_erb_if(self)
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

    class ErbContent < Node
      attr_reader(:value, :unparsed_value)

      def initialize(value:)
        @unparsed_value = value
        begin
          # We cannot handle IfNode inside a ErbContent
          @value =
            if SyntaxTree.search(value, "IfNode").any?
              value&.lstrip&.rstrip
            else
              SyntaxTree.parse(value)
            end
        rescue SyntaxTree::Parser::ParseError
          # Removes leading and trailing whitespace
          @value = value&.lstrip&.rstrip
        end
      end

      def accept(visitor)
        visitor.visit_erb_content(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { value: value }
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

    class HtmlComment < Node
      attr_reader :token, :location

      def initialize(token:, location:)
        @token = token
        @location = location
      end

      def accept(visitor)
        visitor.visit_html_comment(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { token: token, location: location }
      end
    end

    # A CharData contains either plain text or whitespace within an element.
    # It wraps a single token value.
    class CharData < Node
      attr_reader :value, :location

      def initialize(value:, location:)
        @value = value
        @location = location
      end

      def accept(visitor)
        visitor.visit_char_data(self)
      end

      def child_nodes
        [value]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { value: value, location: location }
      end
    end

    # A document type declaration is a special kind of tag that specifies the
    # type of the document. It contains an opening declaration, the name of
    # the document type, an optional external identifier, and a closing of the
    # tag.
    class Doctype < Node
      attr_reader :opening, :name, :closing, :location

      def initialize(opening:, name:, closing:, location:)
        @opening = opening
        @name = name
        @closing = closing
        @location = location
      end

      def accept(visitor)
        visitor.visit_doctype(self)
      end

      def child_nodes
        [opening, name, closing].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { opening: opening, name: name, closing: closing, location: location }
      end
    end
  end
end
