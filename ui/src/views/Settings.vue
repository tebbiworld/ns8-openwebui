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

            <!-- Knowledge base (RAG) -->
            <h4 class="section">{{ $t("settings.rag_section") }}</h4>
            <NsInlineNotification kind="warning" :title="$t('settings.rag_warning_title')" :description="$t('settings.rag_warning_desc')" :showCloseButton="false" class="info-tile" />
            <cv-dropdown
              :label="$t('settings.rag_embedding_engine')"
              v-model="rag_embedding_engine"
              :helper-text="$t('settings.rag_embedding_engine_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            >
              <cv-dropdown-item value="">{{ $t("settings.rag_engine_builtin") }}</cv-dropdown-item>
              <cv-dropdown-item value="ollama">{{ $t("settings.rag_engine_ollama") }}</cv-dropdown-item>
              <cv-dropdown-item value="openai">{{ $t("settings.rag_engine_openai") }}</cv-dropdown-item>
            </cv-dropdown>
            <cv-text-input
              :label="$t('settings.rag_embedding_model')"
              v-model.trim="rag_embedding_model"
              :placeholder="$t('settings.rag_embedding_model_placeholder')"
              :helper-text="$t('settings.rag_embedding_model_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-text-input>
            <cv-number-input
              :label="$t('settings.rag_top_k')"
              v-model="rag_top_k"
              :min="1"
              :max="100"
              :helper-text="$t('settings.rag_top_k_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-number-input>
            <cv-number-input
              :label="$t('settings.rag_chunk_size')"
              v-model="rag_chunk_size"
              :min="1"
              :max="100000"
              :helper-text="$t('settings.rag_chunk_size_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-number-input>
            <cv-number-input
              :label="$t('settings.rag_chunk_overlap')"
              v-model="rag_chunk_overlap"
              :min="0"
              :max="100000"
              :helper-text="$t('settings.rag_chunk_overlap_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-number-input>

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
              <LdapLogin
                v-model="ldap"
                :userDomains="user_domains"
                :bindPasswordSet="ldap_bind_password_set"
                :errors="ldapErrors"
                :disabled="loading.getConfiguration || loading.configureModule"
                ref="ldap"
              />
              <cv-text-input
                :label="$t('settings.ldap_mail_attribute')"
                v-model.trim="ldap_mail_attribute"
                :placeholder="$t('settings.ldap_mail_attribute_placeholder')"
                :helper-text="$t('settings.ldap_mail_attribute_helper')"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="field"
              ></cv-text-input>
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
import LdapLogin, { LDAP_FIELDS, ldapFromConfiguration, validateLdap } from "@/components/LdapLogin";

export default {
  name: "Settings",
  components: { LdapLogin },
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
      enable_signup: false,
      default_user_role: "pending",
      enable_openai_api: false,
      timezone: "UTC",
      rag_embedding_engine: "",
      rag_embedding_model: "",
      rag_top_k: null,
      rag_chunk_size: null,
      rag_chunk_overlap: null,
      ldap_enabled: false,
      ldap_label: "AD / LDAP",
      ldap_mail_attribute: "mail",
      ldap: ldapFromConfiguration({}),
      user_domains: [],
      ldap_bind_password_set: false,
      ldapErrors: {},
      url: "",
      loading: { getConfiguration: false, configureModule: false },
      error: { getConfiguration: "", configureModule: "", host: "" },
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
      this.enable_signup = !!c.enable_signup;
      this.default_user_role = c.default_user_role || "pending";
      this.enable_openai_api = !!c.enable_openai_api;
      this.timezone = c.timezone || "UTC";
      this.rag_embedding_engine = c.rag_embedding_engine || "";
      this.rag_embedding_model = c.rag_embedding_model || "";
      this.rag_top_k = c.rag_top_k != null ? c.rag_top_k : null;
      this.rag_chunk_size = c.rag_chunk_size != null ? c.rag_chunk_size : null;
      this.rag_chunk_overlap = c.rag_chunk_overlap != null ? c.rag_chunk_overlap : null;
      this.ldap_enabled = !!c.ldap_enabled;
      this.ldap_label = c.ldap_label || "AD / LDAP";
      this.ldap_mail_attribute = c.ldap_mail_attribute || "mail";
      this.user_domains = c.user_domains || [];
      this.ldap = ldapFromConfiguration(c);
      this.ldap_bind_password_set = !!c.ldap_bind_password_set;
      this.url = c.url || "";
      this.focusElement("host");
    },
    optInt(value) {
      // An empty number field means "use Open WebUI's own default": send null,
      // not 0 or "".
      if (value === "" || value === null || value === undefined) return null;
      const n = Number(value);
      return Number.isFinite(n) ? n : null;
    },
    validateConfigureModule() {
      this.clearErrors(this);
      this.ldapErrors = {};
      let ok = true;
      const fail = (field, msg) => {
        this.error[field] = msg;
        if (ok) this.focusElement(field);
        ok = false;
      };
      if (!this.host) fail("host", "common.required");
      if (this.ldap_enabled) {
        const ldapErrors = validateLdap(this.ldap, this.ldap_bind_password_set);
        for (const [field, msg] of ldapErrors) this.$set(this.ldapErrors, field, msg);
        if (ldapErrors.length && ok && this.$refs.ldap) this.$refs.ldap.focus(ldapErrors[0][0]);
        if (ldapErrors.length) ok = false;
      }
      return ok;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusSet = false;
      for (const e of validationErrors) {
        if (e.field === "(root)") continue;
        if (LDAP_FIELDS.includes(e.field)) {
          this.$set(this.ldapErrors, e.field, "ldap_login." + e.error);
          if (!focusSet && this.$refs.ldap) {
            this.$refs.ldap.focus(e.field);
            focusSet = true;
          }
        } else {
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
        rag_embedding_engine: this.rag_embedding_engine || "",
        rag_embedding_model: this.rag_embedding_model || "",
        rag_top_k: this.optInt(this.rag_top_k),
        rag_chunk_size: this.optInt(this.rag_chunk_size),
        rag_chunk_overlap: this.optInt(this.rag_chunk_overlap),
        ldap_enabled: this.ldap_enabled,
        ldap_label: this.ldap_label || "AD / LDAP",
        ldap_mail_attribute: this.ldap_mail_attribute || "mail",
        ...this.ldap,
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
