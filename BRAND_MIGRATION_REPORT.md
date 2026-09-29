# AI Meter brand migration

The retired maker name is gone from the current tree. The product name is still AI Meter. The maker line is Jewhurst Engineering.

## References found

### Active public branding (changed)

- About copy in `AppAbout`: product title, organization, copyright, and the unaffiliated disclaimer
- Mac Settings → About, and the faint settings watermark
- iPhone About logo and Developer row
- Mac human-readable copyright in `Info.plist`, `project.yml`, and the Xcode project
- README, extension README, and the Cursor data-source note
- Extension display name, settings title, and the copied usage summary sign-off
- Site footer, lockup alt text, Open Graph card, and structured data
- Wordmarks that rendered the retired maker name
- Settings screenshots whose watermark spelled that name
- The About screenshot, which showed the old About panel in full

### Technical identifiers (changed)

- Bundle IDs are `dev.jewhurst.aimeter.*`
- App groups, the keychain access group, and the keychain service use that same prefix
- Background refresh identifier
- VS Code publisher `jewhurstengineering`. Extension id stays `ai-meter`
- Sparkle feed stays `github.com/JewhurstEngineering/ai-meter`
- Repository slug and GitHub org stay JewhurstEngineering

The next Mac build is a new app identity. Sparkle will not update an already-installed copy. Sessions in the old keychain will not carry over.

### Historical / legal (unchanged)

- `LICENSE` still names James Jewhurst
- Git history and shipped release notes were not rewritten

### URL

- `aiusagemeter.app` stays the live product site and the canonical URL. `jewhurst.dev` did not resolve when this was checked, so the site and app do not link there yet. Maker credit goes to `github.com/JewhurstEngineering`.
- This repo does not link to or request the old maker domain. Nothing in the app, updater, or site depends on it resolving.

## Changed

- Current copy says AI Meter, built by Jewhurst Engineering.
- The color lockup and the social card no longer include the old maker line.
- In-app full wordmarks that used that name were removed. About uses the gauge plus the AI Meter name. The settings watermark is the name only.
- Settings screenshots had that watermark line painted out. Real labels were left alone. A faint AI Meter watermark is still in those shots.
- The About screenshot was taken off the site and the README because the panel itself used the old name.
- Bundle IDs, app groups, keychain identifiers, and the extension publisher no longer use the old maker name.

## Intentionally unchanged

- Sparkle still checks GitHub Releases. The feed URL did not move.
- The product site stays on `aiusagemeter.app` until `jewhurst.dev/ai-meter` exists.
- The MIT license copyright stays James Jewhurst.
- Shipped tags and release notes were not rewritten.

## Redirect dependencies

- `jewhurst.dev` and `jewhurst.dev/ai-meter` are the intended workshop URLs. They were not live on 28 September 2026, so they are not linked yet.
- `aiusagemeter.app` remains the product page this repo deploys.

## Assets still needed

- A new Settings → About screenshot after a build with this copy. The old one was removed rather than faked.
- A `jewhurst.dev/ai-meter` page, then the footer and canonical URL can move there.
- The new App IDs and app groups registered on the Apple developer team before the next signed build.

## Verification

- Extension tests: 30 passed (`tsc` and `node --test` in `vscode/`).
- Mac unit tests: 10 passed, including `AppAboutTests`. Sparkle feed URL still matches GitHub Releases.
- Site HTML parses with matching tags. No browser click-through. The settings switcher is CSS-only.

## Manual QA

- Open Settings → About on Mac and confirm the title is AI Meter, the line under the version is “Built by Jewhurst Engineering,” and the copyright names Jewhurst Engineering.
- Open About on iPhone and confirm the Developer row says Jewhurst Engineering.
- Copy a usage summary from the extension and confirm the last line is `via AI Meter`.
- Load the site, switch every settings tab, and check the footer and the download lockup.
- Confirm Sparkle still points at the GitHub appcast before the next Mac release.
