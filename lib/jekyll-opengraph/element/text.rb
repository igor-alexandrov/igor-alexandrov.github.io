class JekyllOpengraph::Element::Text
  VALID_GRAVITY = %i[nw ne sw se].freeze

  def initialize(canvas, message, gravity: :nw, width: nil, dpi: nil, color: "#000000", font: nil)
    @canvas = canvas
    @gravity = gravity

    validate_gravity!

    text = Vips::Image.text(message,
      font: font,
      width: width,
      dpi: dpi,
      wrap: :word,
      align: :low
    )

    @text = text
      .new_from_image(hex_to_rgb(color))
      .copy(interpretation: :srgb)
      .bandjoin(text)
  end

  def apply(&block)
    result = block.call(@canvas, @text) if block_given?
    x, y = result&.fetch(:x, 0), result&.fetch(:y, 0)

    if gravity_nw?
      @canvas.composite(@text, :over, x: [ x ], y: [ y ]).flatten
    elsif gravity_ne?
      x = @canvas.width - @text.width - x
      @canvas.composite(@text, :over, x: [ x ], y: [ y ]).flatten
    elsif gravity_sw?
      y = @canvas.height - @text.height - y
      @canvas.composite(@text, :over, x: [ x ], y: [ y ]).flatten
    elsif gravity_se?
      x = @canvas.width - @text.width - x
      y = @canvas.height - @text.height - y
      @canvas.composite(@text, :over, x: [ x ], y: [ y ]).flatten
    end
  end

  private

  VALID_GRAVITY.each do |gravity|
    define_method("gravity_#{gravity}?") do
      @gravity == gravity
    end
  end

  def hex_to_rgb(hex)
    hex.match(/#(..)(..)(..)/)[1..3].map { |x| x.hex }
  end

  def validate_gravity!
    unless VALID_GRAVITY.include?(@gravity)
      raise ArgumentError, "Invalid gravity: #{@gravity.inspect}"
    end
  end
end
