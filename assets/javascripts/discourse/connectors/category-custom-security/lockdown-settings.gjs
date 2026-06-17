import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";

export default class LockdownSettings extends Component {
  @service site;
  @tracked lockdownEnabled;

  constructor() {
    super(...arguments);
    this.lockdownEnabled = [true, "true"].includes(
      this.args.outletArgs.category?.custom_fields?.lockdown_enabled
    );
  }

  get availableGroups() {
    return (this.site.groups || [])
      .map((g) => {
        // prevents group "everyone" to be listed
        return g.id === 0 ? null : g.name;
      })
      .filter(Boolean);
  }

  selectedGroups(value) {
    return (value || "").split(",").filter(Boolean);
  }

  @action
  async onToggleEnabled(value, { set, name }) {
    this.lockdownEnabled = value;
    // store "" (which deletes the custom field) when disabled, so the
    // checkbox state stays consistent after a reload
    await set(name, value || "");
  }

  @action
  onChangeGroups(field, values) {
    field.set(values.join(","));
  }

  <template>
    <@outletArgs.form.Section
      @title={{i18n "lockdown.category_setting_heading"}}
      class="lockdown-settings"
    >
      <@outletArgs.form.Object @name="custom_fields" as |object|>
        <object.Field
          @name="lockdown_enabled"
          @title={{i18n "lockdown.lockdown_enabled"}}
          @type="checkbox"
          @format="full"
          @onSet={{this.onToggleEnabled}}
          as |field|
        >
          <field.Control />
        </object.Field>

        {{#if this.lockdownEnabled}}
          <object.Field
            @name="redirect_url"
            @title={{i18n "lockdown.redirect_url"}}
            @type="input"
            as |field|
          >
            <field.Control />
          </object.Field>

          <object.Field
            @name="lockdown_allowed_groups"
            @title={{i18n "lockdown.lockdown_allowed_groups"}}
            @type="custom"
            @format="large"
            as |field|
          >
            <field.Control>
              <GroupChooser
                @content={{this.availableGroups}}
                @valueProperty={{null}}
                @nameProperty={{null}}
                @value={{this.selectedGroups field.value}}
                @onChange={{fn this.onChangeGroups field}}
              />
            </field.Control>
          </object.Field>
        {{/if}}
      </@outletArgs.form.Object>
    </@outletArgs.form.Section>
  </template>
}
