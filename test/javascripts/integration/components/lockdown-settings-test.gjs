import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LockdownSettings from "discourse/plugins/discourse-category-lockdown-nautas/discourse/connectors/category-custom-security/lockdown-settings";

module(
  "Discourse Category Lockdown | Integration | Component | lockdown-settings",
  function (hooks) {
    setupRenderingTest(hooks);

    test("hides the redirect settings when lockdown is disabled", async function (assert) {
      const data = { custom_fields: { lockdown_enabled: false } };
      const category = { custom_fields: data.custom_fields };

      await render(<template>
        <Form @data={{data}} as |form|>
          <LockdownSettings @outletArgs={{hash category=category form=form}} />
        </Form>
      </template>);

      assert.dom(".lockdown-settings").includesText("Category Lockdown");
      assert.dom("input[type=checkbox]").isNotChecked();
      assert
        .dom(".group-chooser")
        .doesNotExist("hides the allowed groups chooser");
    });

    test("reveals the allowed groups chooser when lockdown is enabled", async function (assert) {
      const data = {
        custom_fields: {
          lockdown_enabled: true,
          lockdown_allowed_groups: "",
        },
      };
      const category = { custom_fields: data.custom_fields };

      await render(<template>
        <Form @data={{data}} as |form|>
          <LockdownSettings @outletArgs={{hash category=category form=form}} />
        </Form>
      </template>);

      assert.dom("input[type=checkbox]").isChecked();
      assert.dom(".group-chooser").exists("renders the allowed groups chooser");
    });

    test("toggling the checkbox reveals the fields and writes through the form", async function (assert) {
      const data = { custom_fields: {} };
      const category = { custom_fields: data.custom_fields };
      let submitted = null;

      const onSubmit = (formData) => {
        submitted = formData;
      };

      await render(<template>
        <Form @data={{data}} @onSubmit={{onSubmit}} as |form|>
          <LockdownSettings @outletArgs={{hash category=category form=form}} />
          <form.Submit />
        </Form>
      </template>);

      assert
        .dom(".group-chooser")
        .doesNotExist("fields are hidden before enabling");

      await click("input[type=checkbox]");

      assert
        .dom(".group-chooser")
        .exists("enabling the checkbox reveals the fields");

      await click(".form-kit__button[type='submit']");

      assert.strictEqual(
        submitted?.custom_fields?.lockdown_enabled,
        true,
        "the lockdown_enabled change is routed through the form"
      );
    });
  }
);
