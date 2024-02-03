class JekyllOpengraph::Element::Border
  class Part < Data.define(:rgb, :width, :height, :offset)
  end

  def initialize(canvas, size, position: :bottom, fill: "#000000")
    @canvas = canvas
    @size = size
    @position = position
    @fill = fill

    validate_position!

    @border = Vips::Image.black(*dimensions)

    parts.each.with_index do |part, index|
      border = Vips::Image.black(part.width, part.height).ifthenelse([ 0, 0, 0 ], part.rgb)

      if vertical?
        @border = @border.composite(border, :over, x: [ 0 ], y: [ part.offset ]).flatten
      else
        @border = @border.composite(border, :over, x: [ part.offset ], y: [ 0 ]).flatten
      end
    end
  end

  def apply(&block)
    result = block.call(@canvas, @border) if block_given?
    x, y = result ? [ result.fetch(:x, 0), result.fetch(:y, 0) ] : [ 0, 0 ]

    if vertical?
      x = @position == :left ? x : @canvas.width - @size - x
      @canvas.composite(@border, :over, x: [ x ], y: [ 0 ]).flatten
    else
      y = @position == :top ? y : @canvas.height - @size - y
      @canvas.composite(@border, :over, x: [ 0 ], y: [ y ]).flatten
    end
  end

  def parts
    if @fill.is_a?(Array)
      width, height = vertical? ? [ @size, (@canvas.height / @fill.size) ] : [ (@canvas.width / @fill.size), @size ]

      @fill.map.with_index do |item, index|
        Part.new(
          rgb: hex_to_rgb(item),
          width: width,
          height: height,
          offset: index * (vertical? ? height : width)
        )
      end
    else
      length = vertical? ? @canvas.height : @canvas.width

      [ Part.new(rgb: hex_to_rgb(@fill), length: length, offset: 0) ]
    end
  end

  private

  def hex_to_rgb(hex)
    hex.match(/#(..)(..)(..)/)[1..3].map { |x| x.hex }
  end

  def dimensions
    if vertical?
      [ @size, @canvas.height ]
    else
      [ @canvas.width, @size ]
    end
  end

  def vertical?
    @position == :left || @position == :right
  end

  def horizontal?
    @position == :top || @position == :bottom
  end

  def validate_position!
    unless %i[left right top bottom].include?(@position)
      raise ArgumentError, "Invalid position: #{@position.inspect}"
    end
  end
end
