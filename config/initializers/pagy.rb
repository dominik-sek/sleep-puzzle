# frozen_string_literal: true

# Pagy initializer (43.6.1)
# https://ddnexus.github.io/pagy/toolbox/configuration/initializer/

Pagy::OPTIONS[:limit] = 25

# Pagination::Component writes the limit into every page URL and offers a
# rows-per-page selector; pagy only reads that param back when :client_limit is
# set, which also caps what a client can ask for.
Pagy::OPTIONS[:client_limit] = 100

Pagy::OPTIONS.freeze
