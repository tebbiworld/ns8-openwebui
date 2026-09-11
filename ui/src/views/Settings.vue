<!--
  Copyright (C) 2026 tebbi
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title"><h2>{{ $t("settings.title") }}</h2></cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification kind="error" :title="$t('action.get-configuration')" :description="error.getConfiguration" :showCloseButton="false" />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <!-- Publishing -->
            <cv-text-input
              :label="$t('settings.host')"
              v-model.trim="host"
              :placeholder="$t('settings.host_placeholder')"
              :helper-text="$t('settings.host_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              :invalid-message="$t(error.host)"
              ref="host"
            ></cv-text-input>
            <cv-toggle value="lets_encrypt" :label="$t('settings.lets_encrypt')" v-model="lets_encrypt" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <cv-toggle value="http2https" :label="$t('settings.http2https')" v-model="http2https" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>

            <!-- Backend -->
            <h4 class="section">{{ $t("settings.backend_section") }}</h4>
            <cv-text-input
              :label="$t('settings.ollama_base_url')"
              v-model.trim="ollama_base_url"
              :placeholder="$t('settings.ollama_base_url_placeholder')"
              :helper-text="$t('settings.ollama_base_url_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-text-input>
            <cv-toggle value="enable_openai_api" :label="$t('settings.enable_openai_api')" v-model="enable_openai_api" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>

            <!-- Access -->
            <h4 class="section">{{ $t("settings.access_section") }}</h4>
            <cv-text-input
              :label="$t('settings.webui_name')"
              v-model.trim="webui_name"
              :placeholder="$t('settings.webui_name_placeholder')"
              :helper-text="$t('settings.webui_name_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-text-input>
            <cv-toggle value="enable_signup" :label="$t('settings.enable_signup')" v-model="enable_signup" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <cv-dropdown
              :label="$t('settings.default_user_role')"
              v-model="default_user_role"
              :helper-text="$t('settings.default_user_role_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            >
              <cv-dropdown-item value="pending">{{ $t("settings.role_pending") }}</cv-dropdown-item>
              <cv-dropdown-item value="user">{{ $t("settings.role_user") }}</cv-dropdown-item>
              <cv-dropdown-item value="admin">{{ $t("settings.role_admin") }}</cv-dropdown-item>
            </cv-dropdown>

            <!-- AD / LDAP -->
            <h4 class="section">{{ $t("settings.ldap_section") }}</h4>
            <cv-toggle value="ldap_enabled" :label="$t('settings.ldap_enabled')" v-model="ldap_enabled" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>

            <template v-if="ldap_enabled">
              <cv-text-input
                :label="$t('settings.ldap_label')"
                v-model.trim="ldap_label"
                :placeholder="$t('settings.ldap_label_placeholder')"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="field"
              ></cv-text-input>
              <cv-text-input
                :label="$t('settings.ldap_url')"
                v-model.trim="ldap_url"
                :placeholder="$t('settings.ldap_url_placeholder')"
                :helper-text="$t('settings.ldap_url_helper')"
                :disabled="loading.getConfiguration || loading.configureModule"
                :invalid-message="$t(error.ldap_url)"
                ref="ldap_url"
                class="field"
              ></cv-text-input>
              <cv-text-input
                :label="$t('settings.ldap_base_dn')"
                v-model.trim="ldap_base_dn"
                :placeholder="$t('settings.ldap_base_dn_placeholder')"
                :disabled="loading.getConfiguration || loading.configureModule"
                :invalid-message="$t(error.ldap_base_dn)"
                ref="ldap_base_dn"
                class="field"
              ></cv-text-input>
              <cv-text-input
                :label="$t('settings.ldap_bind_dn')"
                v-model.trim="ldap_bind_dn"
                :placeholder="$t('settings.ldap_bind_dn_placeholder')"
                :disabled="loading.getConfiguration || loading.configureModule"
                :invalid-message="$t(error.ldap_bind_dn)"
                ref="ldap_bind_dn"
                class="field"
              ></cv-text-input>
              <cv-text-input
                type="password"
                :label="$t('settings.ldap_bind_password')"
                v-model="ldap_bind_password"
                :placeholder="ldap_bind_password_set ? $t('settings.secret_keep_placeholder') : ''"
                :helper-text="ldap_bind_password_set ? $t('settings.secret_is_set') : ''"
                :password-hide-label="$t('settings.hide')"
                :password-show-label="$t('settings.show')"
                :disabled="loading.getConfiguration || loading.configureModule"
                :invalid-message="$t(error.ldap_bind_password)"
                ref="ldap_bind_password"
                class="field"
              ></cv-text-input>
              <cv-text-input
                :label="$t('settings.ldap_user_attribute')"
                v-model.trim="ldap_user_attribute"
                :placeholder="$t('settings.ldap_user_attribute_placeholder')"
                :helper-text="$t('settings.ldap_user_attribute_helper')"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="field"
              ></cv-text-input>
              <cv-text-input
                :label="$t('settings.ldap_mail_attribute')"
                v-model.trim="ldap_mail_attribute"
                :placeholder="$t('settings.ldap_mail_attribute_placeholder')"
                :helper-text="$t('settings.ldap_mail_attribute_helper')"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="field"
              ></cv-text-input>
              <cv-text-input
                :label="$t('settings.ldap_search_filter')"
                v-model.trim="ldap_search_filter"
                :placeholder="$t('settings.ldap_search_filter_placeholder')"
                :helper-text="$t('settings.ldap_search_filter_helper')"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="field"
              ></cv-text-input>
              <cv-toggle value="ldap_validate_cert" :label="$t('settings.ldap_validate_cert')" v-model="ldap_validate_cert" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
                <template slot="text-left">{{ $t("settings.disabled") }}</template>
                <template slot="text-right">{{ $t("settings.enabled") }}</template>
              </cv-toggle>
            </template>

            <!-- Misc -->
            <h4 class="section">{{ $t("settings.misc_section") }}</h4>
            <cv-text-input
              :label="$t('settings.timezone')"
              v-model.trim="timezone"
              :placeholder="$t('settings.timezone_placeholder')"
              :helper-text="$t('settings.timezone_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-text-input>

            <NsInlineNotification v-if="url" kind="info" :title="$t('settings.web_url')" :description="$t('settings.web_url_desc', { url })" :showCloseButton="false" class="info-tile" />
            <NsInlineNotification kind="info" :title="$t('settings.models_hint_title')" :description="$t('settings.models_hint_desc')" :showCloseButton="false" class="info-tile" />

            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification kind="error" :title="$t('action.configure-module')" :description="error.configureModule" :showCloseButton="false" />
              </cv-column>
            </cv-row>
            <NsButton kind="primary" :icon="Save20" :loading="loading.configureModule" :disabled="loading.getConfiguration || loading.configureModule">{{ $t("settings.save") }}</NsButton>
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import { QueryParamService, UtilService, TaskService, IconService, PageTitleService } from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [TaskService, IconService, UtilService, QueryParamService, PageTitleService],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: { page: "settings" },
      urlCheckInterval: null,
      host: "",
      lets_encrypt: false,
      http2https: true,
      webui_name: "Open WebUI",
      ollama_base_url: "",
      enable_signup: true,
      default_user_role: "pending",
      enable_openai_api: false,
      timezone: "UTC",
      ldap_enabled: false,
      ldap_label: "AD / LDAP",
      ldap_url: "",
      ldap_base_dn: "",
      ldap_bind_dn: "",
      ldap_bind_password: "",
      ldap_bind_password_set: false,
      ldap_user_attribute: "sAMAccountName",
      ldap_mail_attribute: "mail",
      ldap_search_filter: "",
      ldap_validate_cert: false,
      url: "",
      loading: { getConfiguration: false, configureModule: false },
      error: { getConfiguration: "", configureModule: "", host: "", ldap_url: "", ldap_base_dn: "", ldap_bind_dn: "", ldap_bind_password: "" },
    };
  },
  computed: { ...mapState(["instanceName", "core", "appName"]) },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  created() {
    this.getConfiguration();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, this.getConfigurationAborted);
      this.core.$root.$once(`${taskAction}-completed-${eventId}`, this.getConfigurationCompleted);
      const res = await to(this.createModuleTaskForApp(this.instanceName, { action: taskAction, extra: { title: this.$t("action." + taskAction), isNotificationHidden: true, eventId } }));
      const err = res[0];
      if (err) {
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      this.loading.getConfiguration = false;
      const c = taskResult.output;
      this.host = c.host || "";
      this.lets_encrypt = !!c.lets_encrypt;
      this.http2https = c.http2https !== undefined ? !!c.http2https : true;
      this.webui_name = c.webui_name || "Open WebUI";
      this.ollama_base_url = c.ollama_base_url || "";
      this.enable_signup = c.enable_signup !== undefined ? !!c.enable_signup : true;
      this.default_user_role = c.default_user_role || "pending";
      this.enable_openai_api = !!c.enable_openai_api;
      this.timezone = c.timezone || "UTC";
      this.ldap_enabled = !!c.ldap_enabled;
      this.ldap_label = c.ldap_label || "AD / LDAP";
      this.ldap_url = c.ldap_url || "";
      this.ldap_base_dn = c.ldap_base_dn || "";
      this.ldap_bind_dn = c.ldap_bind_dn || "";
      this.ldap_bind_password_set = !!c.ldap_bind_password_set;
      this.ldap_user_attribute = c.ldap_user_attribute || "sAMAccountName";
      this.ldap_mail_attribute = c.ldap_mail_attribute || "mail";
      this.ldap_search_filter = c.ldap_search_filter || "";
      this.ldap_validate_cert = !!c.ldap_validate_cert;
      this.url = c.url || "";
      // secret is never echoed back — start blank so a blank submit keeps it
      this.ldap_bind_password = "";
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      let ok = true;
      const fail = (field, msg) => {
        this.error[field] = msg;
        if (ok) this.focusElement(field);
        ok = false;
      };
      if (!this.host) fail("host", "common.required");
      if (this.ldap_enabled) {
        if (!this.ldap_url) fail("ldap_url", "common.required");
        if (!this.ldap_base_dn) fail("ldap_base_dn", "common.required");
        if (!this.ldap_bind_dn) fail("ldap_bind_dn", "common.required");
        if (!this.ldap_bind_password && !this.ldap_bind_password_set) fail("ldap_bind_password", "common.required");
      }
      return ok;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusSet = false;
      for (const e of validationErrors) {
        if (e.field !== "(root)") {
          this.error[e.field] = this.$t("settings." + e.error);
          if (!focusSet) {
            this.focusElement(e.field);
            focusSet = true;
          }
        }
      }
    },
    async configureModule() {
      if (!this.validateConfigureModule()) return;
      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, this.configureModuleAborted);
      this.core.$root.$once(`${taskAction}-validation-failed-${eventId}`, this.configureModuleValidationFailed);
      this.core.$root.$once(`${taskAction}-completed-${eventId}`, this.configureModuleCompleted);
      const data = {
        host: this.host,
        lets_encrypt: this.lets_encrypt,
        http2https: this.http2https,
        webui_name: this.webui_name || "Open WebUI",
        ollama_base_url: this.ollama_base_url,
        enable_signup: this.enable_signup,
        default_user_role: this.default_user_role,
        enable_openai_api: this.enable_openai_api,
        timezone: this.timezone || "UTC",
        ldap_enabled: this.ldap_enabled,
        ldap_label: this.ldap_label,
        ldap_url: this.ldap_url,
        ldap_base_dn: this.ldap_base_dn,
        ldap_bind_dn: this.ldap_bind_dn,
        ldap_bind_password: this.ldap_bind_password,
        ldap_user_attribute: this.ldap_user_attribute,
        ldap_mail_attribute: this.ldap_mail_attribute,
        ldap_search_filter: this.ldap_search_filter,
        ldap_validate_cert: this.ldap_validate_cert,
      };
      const res = await to(this.createModuleTaskForApp(this.instanceName, {
        action: taskAction,
        data,
        extra: { title: this.$t("settings.configure_instance", { instance: this.instanceName }), description: this.$t("common.processing"), eventId },
      }));
      const err = res[0];
      if (err) {
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.field { margin-top: $spacing-06; }
.toggle { margin-top: $spacing-06; }
.info-tile { margin-top: $spacing-06; }
.section { margin-top: $spacing-07; margin-bottom: $spacing-03; }
</style>
