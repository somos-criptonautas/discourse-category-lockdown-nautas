import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";

// Only rendered for readers who cannot see the whispered replies: the server
// omits these fields for everyone else, so a missing count is the signal to
// stay out of the way. Shows who is taking part, never any of what they wrote.
export default class LockdownHiddenReplies extends Component {
  get count() {
    return this.args.outletArgs.model?.lockdown_hidden_reply_count;
  }

  get participants() {
    return this.args.outletArgs.model?.lockdown_hidden_reply_participants;
  }

  get shownUsers() {
    return this.participants?.users ?? [];
  }

  get participantsLabel() {
    const shown = this.shownUsers;
    if (shown.length === 0) {
      return null;
    }

    const names = shown.map((user) => user.username).join(", ");
    const others = (this.participants.total ?? shown.length) - shown.length;

    return i18n("lockdown.hidden_replies.participants", {
      names,
      count: others,
    });
  }

  <template>
    {{#if this.count}}
      <section class="lockdown-hidden-replies">
        {{#if this.shownUsers}}
          <div class="lockdown-hidden-replies__avatars">
            {{#each this.shownUsers as |user|}}
              <span class="lockdown-hidden-replies__avatar">
                {{dBoundAvatarTemplate user.avatar_template "medium"}}
              </span>
            {{/each}}
          </div>
        {{/if}}

        <h3 class="lockdown-hidden-replies__title">
          {{icon "far-comments"}}
          {{i18n "lockdown.hidden_replies.title" count=this.count}}
        </h3>

        {{#if this.participantsLabel}}
          <p class="lockdown-hidden-replies__participants">
            {{this.participantsLabel}}
          </p>
        {{/if}}

        <p class="lockdown-hidden-replies__body">
          {{i18n "lockdown.hidden_replies.body"}}
        </p>
      </section>
    {{/if}}
  </template>
}
