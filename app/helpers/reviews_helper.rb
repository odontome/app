module ReviewsHelper
  def ratings_widget(value = 0, size = 25)
    content = ''

    (1..value).each do |_i|
      content += image_tag 'rating-star-filled@2x.png', width: size
    end

    (1..(5 - value)).each do |_i|
      content += image_tag 'rating-star@2x.png', width: size
    end

    content.html_safe
  end
end
