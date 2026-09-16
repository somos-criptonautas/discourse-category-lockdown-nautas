import { withPluginApi } from "discourse/lib/plugin-api";
import { default as DiscourseURL } from "discourse/lib/url";

const PLUGIN_ID = "discourse-category-lockdown-nautas";

function initializeLockdown(api) {
  // Intercept any HTTP 402 (Payment Required) responses for topics
  // And redirect the client accordingly

  api.registerBehaviorTransformer(
    "post-stream-error-loading",
    ({ next, context }) => {
      const status = context.error.jqXHR.status;
      let response = context.error.jqXHR.responseJSON;

      if (status === 402) {
        const redirectURL = response.redirect_url || "/";
        return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
      }
      next();
    }
  );

  api.registerValueTransformer(
    "topic-list-item-class",
    ({ value, context }) => {
      if (context.topic.get("is_locked_down")) {
        value.push("locked-down");
      }
      return value;
    }
  );

  // Replies in these categories are whispers, so replying to one puts the
  // composer into whisper mode: an eye-slash save icon and a "whisper" save
  // label. Every one of those comes from isWhispering, and none of them mean
  // anything here, where the whole discussion is whispered. This only changes
  // how the composer presents itself - the post is still sent and stored as a
  // whisper, by the composer model and by the server independently of it.
  api.modifyClass(
    "service:composer",
    (Superclass) =>
      class extends Superclass {
        get isWhispering() {
          if (this.model?.category?.lockdown_whisper_replies) {
            return false;
          }
          return super.isWhispering;
        }
      }
  );

  if (api.container.factoryFor("route:docs-index")) {
    api.modifyClass("route:docs-index", {
      pluginId: PLUGIN_ID,
      model(params, transition) {
        return this._super(params).catch((error) => {
          let response = error.jqXHR.responseJSON;
          const status = error.jqXHR.status;
          if (status === 402) {
            // abort the transition to prevent momentary error
            // from being displayed
            transition.abort();
            const redirectURL = response.redirect_url || "/";
            return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
          }
        });
      },
    });
  }
}

export default {
  name: "apply-lockdown",

  initialize() {
    withPluginApi("1.35.0", initializeLockdown);
  },
};
