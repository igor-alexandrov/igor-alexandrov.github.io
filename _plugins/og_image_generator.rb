return if ENV['JEKYLL_ENV'] == "production"

require "./lib/jekyll-opengraph/image"

module SamplePlugin
  class OgImageGenerator < Jekyll::Generator
    def generate(site)
      FileUtils.mkdir_p "assets/og-images/posts"

      site.posts.docs.each do |post|
        filename = "assets/og-images/posts/#{post.data['slug']}.png"
        generate_image_for_post(site, post, filename)

        post.data['image'] ||= {
          'path' => filename,
          'width' => 1200,
          'height' => 600,
          'alt' => post.data['title']
        }
      end
    end

    private

    def generate_image_for_post(site, post, path)
      date = post.date.strftime("%B %d, %Y")

      image = JekyllOpengraph::Image.new(1200, 600)
        .border(20, position: :bottom, fill: [ '#820C02', '#A91401', '#D51F06', '#DE3F24', '#EDA895', '#FFFFFF' ])
        .text(post.data['title'], width: 1040, color: "#2f313d", dpi: 500, font: 'Helvetica, Bold') do |_canvas, _text|
          {
            x: 80,
            y: 100
          }
        end
        .text(date, gravity: :sw, color: "#535358", dpi: 200, font: 'Helvetica, Regular') do |_canvas, _text|
          {
            x: 80,
            y: post.data['tags'].any? ? 150 : 100
          }
        end

      if post.data['tags'].any?
        tags = post.data['tags'].map { |tag| "##{tag}" }.join(" ")

        image = image.text(tags, gravity: :sw, color: "#535358", dpi: 150, font: 'Helvetica, Regular') do |_canvas, _text|
          {
            x: 80,
            y: 100
          }
        end
      end

      image = image.text('igor.works', gravity: :se, color: "#535358", dpi: 200, font: 'Helvetica, Regular') do |_canvas, _text|
        {
          x: 80,
          y: post.tags.any? ? 150 : 100
        }
      end

      image.save(path)
    end
  end
end
