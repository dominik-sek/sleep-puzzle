# The public routes sit under an optional `(:locale)` segment, and an optional
# *leading* dynamic segment swallows the first positional argument: without this,
# `product_path(product)` binds the product to :locale and raises "missing
# required keys: [:id]".
#
# Declaring the key here — nil, so Polish paths stay unprefixed — means the
# segment is always considered supplied, and positional arguments land on the
# segment they were written for. ApplicationController#default_url_options
# overrides it per request for a non-default locale.
#
# It belongs at the routes level rather than only in the controller because
# mailers, jobs and specs generate URLs without a controller and would otherwise
# hit the same binding bug.
Rails.application.routes.default_url_options[:locale] = nil
