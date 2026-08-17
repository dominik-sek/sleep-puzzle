module NavigationHelper
  # The public site's primary navigation, in order.
  #
  # Kept here rather than in shared/_navbar because the partial renders this list
  # twice — once inline for the bar, once inside the hamburger panel — and two
  # hand-written copies drift the first time a link is added.
  #
  # Blog is designed but parked, so its entry stays commented out alongside the
  # markup that would render it.
  def primary_nav_items
    [
      { label: "Pakiety", href: packages_path },
      { label: "O mnie", href: about_path },
      # { label: "Blog", href: blog_path },
      { label: "Sklep", href: products_path },
      { label: "Kontakt", href: contact_path }
    ]
  end

  # One row in the profile dropdown. Shared by the links and the sign-out button so
  # the two cannot drift — a hand-styled anchor next to a form-wrapped button was
  # what made the menu look uneven.
  #
  # w-full + text-left matter because `button_to` renders its button inside a form:
  # without them that row shrinks to its label while its neighbours fill the panel.
  def profile_menu_item_classes
    "flex w-full items-center gap-2.5 rounded-md px-3 py-2.5 text-left text-sm font-semibold " \
      "text-cream no-underline cursor-pointer bg-transparent border-0 hover:bg-ink-soft hover:text-accent"
  end

  # The same row, sized for the hamburger panel, where the type is a step larger.
  def mobile_menu_item_classes
    "flex w-full items-center gap-3 rounded-md px-3 py-2.5 text-left text-md font-bold " \
      "text-cream no-underline cursor-pointer bg-transparent border-0 hover:bg-ink-soft hover:text-accent"
  end
end
