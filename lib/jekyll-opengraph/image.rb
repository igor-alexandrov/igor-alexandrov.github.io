require "vips"

module JekyllOpengraph
  class Image
    attr_reader :canvas

    def initialize(width, height, color: "#ffffff")
      @canvas = Vips::Image.black(width, height).ifthenelse([ 0, 0, 0 ], hex_to_rgb(color))
    end

    def text(message, **opts, &block)
      text = JekyllOpengraph::Element::Text.new(
        @canvas, message, **opts
      )

      @canvas = text.apply(&block)

      self
    end

    def border(size, position: :bottom, color: "#000000")
      @canvas = JekyllOpengraph::Element::Border.new(
        @canvas, size,
        position: position,
        color: color
      ).apply

      self
    end

    def save(filename)
      @canvas.write_to_file(filename)
    end

    private

    def hex_to_rgb(input)
      case input
      when String
        input.match(/#(..)(..)(..)/)[1..3].map(&:hex)
      when Array
        input
      else
        raise ArgumentError, "Unknown input #{input.inspect}"
      end
    end
  end
end

require_relative "element"
