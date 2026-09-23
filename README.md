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

## Requirements

Tested against Discourse `main` on every push via the standard plugin CI workflow.
Older lines are **not supported**: this fork uses current plugin-API and import paths,
and it previously shipped pinned upstream-era commits to pre-3.4 installs — commits that
still contained the external redirect this README describes as removed. Those pins have
been deleted rather than left to contradict the text above.

## Two independent modes

A category uses one or the other. They are configured separately and do not interact.

### Lockdown — hide the whole topic

Non-members are redirected to the category description topic. The category and its topic
titles stay publicly listed, which is the point: it is a paywall with a funnel, not a
private category.

Because the category stays readable, the query paths that build SQL directly do not see
the plugin's `Guardian` override. Search, the `/posts.json` firehose and user activity
streams are filtered explicitly (`Search`, `LatestPostsQuery`, `UserAction`), each with a
regression spec. **If you add a feature that exposes post content through a new query
path, it will not be covered by the `Guardian` override — check it.**

### Keep replies private — public first post, private replies

Per category, under **Settings → Security**. The first post of each topic stays public;
every reply is created as a core **whisper**. Built for a published course whose lessons
are public and whose support discussion is for subscribers.

Because replies are whispers, core excludes them from search, feeds, digests and stream
endpoints for readers who cannot see whispers — no per-path patching needed.

**This mode depends on the `whispers_allowed_groups` site setting.** Readers who can see
whispers are exactly the members of those groups, *not* the category's
`lockdown_allowed_groups`. Two consequences:

- Add your subscribers **and your instructors** to `whispers_allowed_groups`. Admins are
  whisperers automatically; **non-admin moderators are not**, and will silently not see
  the replies they are meant to answer.
- It is one global list, so this mode cannot give different categories different reader
  groups. Lockdown mode can.

Visitors see a teaser above the suggested topics: how many replies exist and who is
taking part (avatars and usernames, never any of what they wrote). Note this reveals who
is enrolled. Reword it in **Admin → Customize → Text** under `lockdown.hidden_replies`.

#### Turning it on for a category that already has replies

Replies posted before you enable it are ordinary posts and stay public. Convert them:

```bash
rake category_lockdown:whisper_existing_replies[123,dry_run]   # count first
rake category_lockdown:whisper_existing_replies[123]
```

#### Site-wide styling note

The plugin ships CSS that neutralises core's whisper styling (the indicator and the
italic muted body text) so course replies read as ordinary posts. **It is global**, on
the assumption that you do not also use whispers for moderation notes. If you do, scope
those rules in `assets/stylesheets/common/category-lockdown.scss`.

## Settings

| Setting | Purpose |
| --- | --- |
| `category_lockdown_enabled` | Master switch for the plugin. |
| `category_lockdown_list_icon` | FontAwesome icon shown next to locked topics in lists. |
| `category_lockdown_allow_crawlers` | Let search engine crawlers read locked topics. **Crawlers are identified by User-Agent alone, which anyone can send** — on its own this exemption is advisory, not enforced. |
| `category_lockdown_crawler_require_verified_ip` | Also require the request to come from an ASN in core's `crawler_asns` setting. Closes the User-Agent bypass — but nothing qualifies as a crawler until `crawler_asns` is populated. |
| `category_lockdown_crawler_noarchive` | Send `<meta name="robots" content="noarchive">`. |
| `category_lockdown_crawler_indicate_paywall` | Emit schema.org `isAccessibleForFree: False`. |

Per category, under **Settings → Security**: enable lockdown and pick the groups allowed
to read it. Admins always have access; **moderators do not** — lockdown checks group
membership, and allowed groups are matched **by name**, so renaming a group revokes
access (it fails closed).

## Removing the plugin

Disabling `category_lockdown_enabled` stops every behaviour. Nothing is destroyed:
category custom fields remain, and replies already converted to whispers **stay
whispers** — they do not revert to public posts. Reverse that with SQL if you need to.

## Upstream

Original plugin discussion: https://meta.discourse.org/t/discourse-category-lockdown/70649

To pull upstream changes:

```bash
git remote add upstream https://github.com/paviliondev/discourse-category-lockdown.git
git fetch upstream
```
