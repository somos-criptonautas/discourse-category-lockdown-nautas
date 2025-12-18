import { withPluginApi } from "discourse/lib/plugin-api";
import { default as DiscourseURL } from "discourse/lib/url";

const PLUGIN_ID = "discourse-category-lockdown";

function initializeLockdown(api) {
  // Intercept any HTTP 402 (Payment Required) responses for topics
  // And redirect the client accordingly

  const siteSettings = api.container.lookup("service:site-settings");
  api.registerBehaviorTransformer(
    "post-stream-error-loading",
    ({ next, context }) => {
      const status = context.error.jqXHR.status;
      let response = context.error.jqXHR.responseJSON;

      if (status === 402) {
        let redirectURL = response.redirect_url ||
          siteSettings.category_lockdown_redirect_url;
        const external = redirectURL.startsWith("http");
        if (external) {
          // Use location.replace so that the user can go back in one click
          document.location.replace(redirectURL);
          return;
        } else {
          // Handle the redirect inside ember
          return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
        }
      }
      next();
    }
  );

  api.registerValueTransformer("topic-list-item-class",
    ({value, context}) => {
      if (context.topic.get("is_locked_down")) {
        value.push("locked-down");
      }
      return value;
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
            let redirectURL =
              response.redirect_url ||
              this.siteSettings.category_lockdown_redirect_url;

            const external = redirectURL.startsWith("http");
            if (external) {
              document.location.href = redirectURL;
            } else {
              // Handle the redirect inside ember
              return DiscourseURL.handleURL(redirectURL, { replaceURL: true });
            }
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
