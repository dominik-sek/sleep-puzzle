# Editable content

`config/content_blocks.yml` **is the schema** - no Ruby names any field. 

Meaning
comes from depth: level 1 is a page, level 2 (under `sections:`) a section, level 3
(under `fields:`) a field.

```yaml
footer:                 # page
  label: Stopka
  sections:
    brand:              # section
      label: Pod logo
      fields:
        tagline:        # field
          label: Opis
          type: plain
          default:
            pl: "Pomagam rodzinom…"
            en: "Helping families…"
```

Read it in a view with:
- `content_block("footer.brand.tagline")` 
- `content_image` for`image` fields,
- `content_items` for a collection. 
 
That works as soon as the lines are
in the YAML: with no row in the database the helper renders the declared `default:`

`bin/rails content_blocks:sync` pre-creates a blank row per declared key and populates
collection defaults. 

It is optional for plain and rich fields - the panel creates the
row the first time the owner saves - and idempotent, so it never touches copy anyone
has written.

## Types of content
- plain text
- rich text (Trix)
- image upload (one per language)
- repeating list (collection)

example of collection:
```yaml
    stats:
      label: Liczby
      collection:
        item_label: Liczba
        fields:
          text:
            label: Treść
            type: plain
        defaults:
          - text:
              pl: "20+ lat"
```

### Notes
* `label:` is required at every level; `default:` is optional, and `en` falls back
  to `pl`.
* A section with no `fields:` can hold a `collection:` instead - a repeating list the
  owner can add to (see `home.stats`). A collection with no rows renders its declared
  defaults, and they are materialised the first time anyone adds to it.
* Order follows the file. Unknown types and missing labels raise at boot; an unknown
  key raises in development and test and is ignored in production.

>New pages must add their own entry, or they aren't editable.
 
Anything static belongs in `pl.yml`/`en.yml` instead.
