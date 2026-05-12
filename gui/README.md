
## GOV.UK-flavoured styling (live)

The live demonstrator at `state-pension-demo.thedarkfactory.dev` uses
`govuk-style.css` — a GOV.UK Design System–inspired stylesheet (typography,
colour, layout). NOT affiliated with the Government Digital Service.
Demonstrator copy explicitly prefixed *DEMONSTRATOR — NOT A GOVERNMENT
SERVICE*.

### How it's wired

The stylesheet ships as a sibling file to the Gnoga static assets and is
linked from Gnoga's `boot.html`. Two manual deployment steps after the
binary is in place at `/opt/state-pension-demo/exe/`:

1. Copy `govuk-style.css` into the runtime's `css/` directory:
   ```bash
   cp gui/govuk-style.css /opt/state-pension-demo/exe/css/govuk-style.css
   ```

2. Add a stylesheet link to the runtime's `boot.html`:
   ```html
   <link rel="stylesheet" href="/css/govuk-style.css">
   ```
   (Drop it right after the favicon link in `boot.html`'s `<head>`.)

3. The systemd service does not need restarting — Gnoga serves static
   assets fresh on every connection.

### Known visual quirks worth knowing

- The "DEMONSTRATOR ONLY." prefix in the Ada `Disclaimer_Banner` constant
  is now redundant with the CSS-injected "DEMONSTRATOR — NOT A GOVERNMENT
  SERVICE" phase tag. Cleaning that up needs an Ada edit + binary rebuild.
- Pre-submission, empty result-row divs pick up the CSS row-divider
  styling and render as a couple of faint grey lines. Easy CSS-only fix
  with `:empty` if it becomes annoying.
