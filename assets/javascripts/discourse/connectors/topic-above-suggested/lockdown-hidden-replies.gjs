import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

// Only rendered for readers who cannot see the whispered replies: the server
// omits lockdown_hidden_reply_count for everyone else, so an empty or missing
// count is the signal to stay out of the way.
export default class LockdownHiddenReplies extends Component {
  get count() {
    return this.args.outletArgs.model?.lockdown_hidden_reply_count;
  }

  <template>
    {{#if this.count}}
      <section class="lockdown-hidden-replies">
        <h3 class="lockdown-hidden-replies__title">
          {{icon "far-comments"}}
          {{i18n "lockdown.hidden_replies.title" count=this.count}}
        </h3>
        <p class="lockdown-hidden-replies__body">
          {{i18n "lockdown.hidden_replies.body"}}
        </p>
      </section>
    {{/if}}
  </template>
}
