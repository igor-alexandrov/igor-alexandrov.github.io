return if jekyll.environment == "production"

require "./lib/jekyll-opengraph/image"

module SamplePlugin
  class OgImageGenerator < Jekyll::Generator
    def generate(site)
      FileUtils.mkdir_p "assets/og-images/posts"

      site.posts.docs.each do |post|
        filename = "assets/og-images/posts/#{post.slug}.png"

        date = post.date.strftime("%B %d, %Y")

        image = JekyllOpengraph::Image.new(1200, 600)
          .border(20, position: :bottom, color: '#d51f06')
          .text(post.title, width: 1040, color: "#2f313d", dpi: 500, font: 'Helvetica, Bold') do |_canvas, _text|
            {
              x: 80,
              y: 100
            }
          end
          .text(date, gravity: :sw, color: "#535358", dpi: 200, font: 'Helvetica, Regular') do |_canvas, _text|
            {
              x: 80,
              y: post.tags.any? ? 150 : 100
            }
          end

        if post.tags.any?
          tags = post.tags.map { |tag| "##{tag}" }.join(" ")

          image = image.text(tags, gravity: :sw, color: "#535358", dpi: 150, font: 'Helvetica, Regular') do |_canvas, _text|
            {
              x: 80,
              y: 100
            }
          end

          image = image.text(site.baseurl, gravity: :se, color: "#535358", dpi: 150, font: 'Helvetica, Regular') do |_canvas, _text|
            {
              x: 80,
              y: post.tags.any? ? 150 : 100
            }
          end
        end

        image.save(filename)
      end
    end
  end
end
