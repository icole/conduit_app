module AvatarHelper
  # A person's photo in a circle, or their initials when they have no photo.
  # If the photo fails to load (Google profile photo links expire), the
  # avatar controller swaps in the initials.
  #   size:           width class for the circle (it's square)
  #   text:           size class for the initials
  #   initials_class: colours behind the initials
  def user_avatar(user, size: "w-8", text: "text-xs", initials_class: "bg-neutral text-neutral-content", **options)
    photo = user.avatar_url.presence
    initials = tag.span(initials_for(user.name), class: text, hidden: photo.present?, data: { avatar_target: "initials" })

    tag.div(class: [ "avatar avatar-placeholder shrink-0", options[:class] ], data: { controller: "avatar" }) do
      tag.div(class: "#{size} rounded-full #{initials_class}") do
        safe_join([
          (tag.img(src: photo, alt: "", class: "w-full h-full object-cover", data: { avatar_target: "photo", action: "error->avatar#fallback" }) if photo),
          initials
        ].compact)
      end
    end
  end

  # "Jane Smith" -> "JS", "Liz" -> "L"
  def initials_for(name)
    words = name.to_s.split
    [ words.first, (words.last if words.size > 1) ].compact.map { |word| word[0] }.join.upcase
  end
end
