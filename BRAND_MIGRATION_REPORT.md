# AI Meter brand migration

JamesWare is no longer the maker on current AI Meter surfaces. The product name is still AI Meter. The maker line is Jewhurst Engineering.

## References found

### Active public branding (changed)

- About copy in `AppAbout`: product title, organization, copyright, and the unaffiliated disclaimer
- Mac Settings → About, and the faint settings watermark
- iPhone About logo and Developer row
- Mac human-readable copyright in `Info.plist`, `project.yml`, and the Xcode project
- README, extension README, and the Cursor data-source note
- Extension display name, settings title, and the copied usage summary sign-off
- Site footer, lockup alt text, Open Graph card, and structured data
- Wordmarks that rendered the word JamesWare
- Settings screenshots whose watermark spelled JamesWare
- The About screenshot, which showed the old About panel in full

### Stable technical identifiers (unchanged)

- Bundle IDs, `com.jamesware.aimeter.*`
- App groups and the keychain access group / service name
- Background refresh identifier
- VS Code publisher `jamesware` and extension id `ai-meter`
- Sparkle feed, still `github.com/JewhurstEngineering/ai-meter`
- Repository slug and GitHub org

Renaming any of those would break upgrades, signing, keychain access, or an already-installed extension.

### Historical / legal (unchanged)

- `LICENSE` still names James Jewhurst
- Git history and shipped release notes were not rewritten

### URL

- `aiusagemeter.app` stays the live product site and the canonical URL. `jewhurst.dev` did not resolve when this was checked, so the site and app do not link there yet. Maker credit goes to `github.com/JewhurstEngineering`.
- This repo does not link to or request the old maker domain. Nothing in the app, updater, or site depends on it resolving.

## Changed

- Current copy says AI Meter, built by Jewhurst Engineering.
- The color lockup and the social card no longer include the JamesWare line.
- In-app full wordmarks that said JamesWare were removed. About uses the gauge plus the AI Meter name. The settings watermark is the name only.
- Settings screenshots had the JamesWare watermark line painted out. Real labels were left alone. A faint AI Meter watermark is still in those shots.
- The About screenshot was taken off the site and the README because the panel itself said JamesWare.
- The site download `ai-meter-0.1.6.vsix` was repackaged from this source. The extension still publishes as `jamesware`, so installs keep the same id.

## Intentionally unchanged

- Bundle IDs, app groups, keychain identifiers, and the extension publisher. Those are how installs, widgets, and updates find each other.
- Sparkle still checks GitHub Releases. The feed URL did not move.
- The product site stays on `aiusagemeter.app` until `jewhurst.dev/ai-meter` exists.
- The MIT license copyright stays James Jewhurst.

## Redirect dependencies

- `jewhurst.dev` and `jewhurst.dev/ai-meter` are the intended workshop URLs. They were not live on 28 September 2026, so they are not linked yet.
- `aiusagemeter.app` remains the product page this repo deploys.

## Assets still needed

- A new Settings → About screenshot after a build with this copy. The old one was removed rather than faked.
- A `jewhurst.dev/ai-meter` page, then the footer and canonical URL can move there.

## Verification

- Extension tests: 30 passed (`tsc` and `node --test` in `vscode/`).
- Mac unit tests: 10 passed, including `AppAboutTests`. Sparkle feed URL still matches GitHub Releases.
- Site HTML parses with matching tags. No browser click-through. The settings switcher is CSS-only.

## Manual QA

- Open Settings → About on Mac and confirm the title is AI Meter, the line under the version is “Built by Jewhurst Engineering,” and the copyright names Jewhurst Engineering.
- Open About on iPhone and confirm the Developer row says Jewhurst Engineering and the logo does not say JamesWare.
- Copy a usage summary from the extension and confirm the last line is `via AI Meter`.
- Load the site, switch every settings tab, and check the footer and the download lockup.
- Confirm Sparkle still points at the GitHub appcast before the next Mac release.
