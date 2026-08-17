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
end
