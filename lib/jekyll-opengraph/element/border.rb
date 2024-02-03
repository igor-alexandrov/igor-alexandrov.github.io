class JekyllOpengraph::Element::Border
  def initialize(canvas, size, position: :bottom, color: "#000000")
    @canvas = canvas
    @size = size
    @position = position
    @color = color

    validate_position!

    @border = Vips::Image.black(*dimensions).ifthenelse([ 0, 0, 0 ], hex_to_rgb(@color))
  end

  def apply(&block)
    result = block.call(@canvas, @border) if block_given?
    x, y = result&.fetch(:x, 0), result&.fetch(:y, 0)

    if vertical?
      x = @position == :left ? x : @canvas.width - @size - x
      @canvas.composite(@border, :over, x: [ x ], y: [ 0 ]).flatten
    else
      y = @position == :top ? y : @canvas.height - @size - y
      @canvas.composite(@border, :over, x: [ 0 ], y: [ y ]).flatten
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
