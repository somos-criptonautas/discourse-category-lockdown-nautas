# discourse-category-lockdown-nautas

Lock down every topic in a category so that only members of specified groups can read
them. Everyone else is redirected to the category's own description topic.

Fork of [paviliondev/discourse-category-lockdown](https://github.com/paviliondev/discourse-category-lockdown),
maintained for [criptonautas.co](https://criptonautas.co).

## How this fork differs

**Upstream** redirects blocked visitors to an operator-configured URL — a
`category_lockdown_redirect_url` site setting, optionally overridden per category by a
`redirect_url` custom field. Any URL was accepted, including external ones, so the
redirect was performed with `allow_other_host: true`.

**This fork** removes both of those and always redirects to the category's own
description topic ("About the … category"). The fallback chain is:

1. the category description topic, if it exists and the visitor can see it;
2. the category page, if the visitor can see the category;
3. the site root.

Consequences:

- **The destination is always same-origin.** Nothing user- or content-supplied reaches
  `redirect_to`, and `allow_other_host` is gone. The upstream setting was an
  admin-controlled open redirect; this closes it.
- **The redirect target explains itself.** Blocked visitors land on the text the category
  owner already wrote to describe the category, rather than a generic marketing page that
  has to be kept in sync by hand.
- **No configuration.** One less site setting and one less category field to get wrong.
  A category's description topic is created by Discourse automatically.
- **The description topic is never locked.** It is exempted inside
  `CategoryLockdown.is_locked`, so the redirect cannot loop and the destination cannot
  404. Note that this exempts the whole topic, replies included — don't post anything
  private in a locked category's description topic.

## Settings

| Setting | Purpose |
| --- | --- |
| `category_lockdown_enabled` | Master switch for the plugin. |
| `category_lockdown_list_icon` | FontAwesome icon shown next to locked topics in lists. |
| `category_lockdown_allow_crawlers` | Let search engine crawlers read locked topics. |
| `category_lockdown_crawler_noarchive` | Send `<meta name="robots" content="noarchive">`. |
| `category_lockdown_crawler_indicate_paywall` | Emit schema.org `isAccessibleForFree: False`. |

Per category, under **Settings → Security**: enable lockdown and pick the groups allowed
to read it. Admins always have access.

## Upstream

Original plugin discussion: https://meta.discourse.org/t/discourse-category-lockdown/70649

To pull upstream changes:

```bash
git remote add upstream https://github.com/paviliondev/discourse-category-lockdown.git
git fetch upstream
```
