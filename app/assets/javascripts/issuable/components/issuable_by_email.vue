<script>
import {
  GlButton,
  GlModal,
  GlModalDirective,
  GlTooltipDirective,
  GlSprintf,
  GlLink,
  GlFormInputGroup,
  GlIcon,
} from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { sprintf, __ } from '~/locale';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';

export default {
  i18n: {
    sendEmail: __('Send email'),
  },
  name: 'IssuableByEmail',
  components: {
    GlButton,
    GlModal,
    GlSprintf,
    GlLink,
    GlFormInputGroup,
    GlIcon,
    ModalCopyButton,
  },
  directives: {
    GlModal: GlModalDirective,
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    initialEmail: {
      default: null,
    },
    issuableType: {
      default: '',
    },
    emailsHelpPagePath: {
      default: '',
    },
    quickActionsHelpPath: {
      default: '',
    },
    markdownHelpPath: {
      default: '',
    },
    resetPath: {
      default: '',
    },
  },
  data() {
    return {
      email: this.initialEmail,
      // eslint-disable-next-line @gitlab/require-i18n-strings
      issuableName: this.issuableType === 'issue' ? 'issue' : 'merge request',
    };
  },
  computed: {
    mailToLink() {
      const subject = sprintf(__('Enter the %{name} title'), {
        name: this.issuableName,
      });
      const body = sprintf(__('Enter the %{name} description'), {
        name: this.issuableName,
      });
      // eslint-disable-next-line @gitlab/require-i18n-strings
      return `mailto:${this.email}?subject=${subject}&body=${body}`;
    },
  },
  methods: {
    async resetIncomingEmailToken() {
      try {
        const {
          data: { new_address: newAddress },
        } = await axios.put(this.resetPath);
        this.email = newAddress;
      } catch {
        this.$toast.show(__('There was an error when reseting email token.'), { type: 'error' });
      }
    },
    cancelHandler() {
      this.$refs.modal.hide();
    },
  },
  modalId: 'issuable-email-modal',
};
</script>

<template>
  <div>
    <gl-button v-gl-modal="$options.modalId" variant="link"
      ><gl-sprintf :message="__('Email a new %{name} to this project')"
        ><template #name>{{ issuableName }}</template></gl-sprintf
      ></gl-button
    >
    <gl-modal ref="modal" :modal-id="$options.modalId">
      <template #modal-title>
        <gl-sprintf :message="__('Create new %{name} by email')">
          <template #name>{{ issuableName }}</template>
        </gl-sprintf>
      </template>
      <p>
        <gl-sprintf
          :message="
            __(
              'You can create a new %{name} inside this project by sending an email to the following email address:',
            )
          "
        >
          <template #name>{{ issuableName }}</template>
        </gl-sprintf>
      </p>
      <gl-form-input-group :value="email" readonly select-on-click class="gl-mb-4">
        <template #append>
          <modal-copy-button :text="email" :title="__('Copy')" :modal-id="$options.modalId" />
          <gl-button
            v-gl-tooltip.hover
            :href="mailToLink"
            :title="$options.i18n.sendEmail"
            :aria-label="$options.i18n.sendEmail"
            icon="mail"
          />
        </template>
      </gl-form-input-group>
      <p>
        <gl-sprintf
          :message="
            __(
              'The subject will be used as the title of the new issue, and the message will be the description. %{quickActionsLinkStart}Quick actions%{quickActionsLinkEnd} and styling with %{markdownLinkStart}Markdown%{markdownLinkEnd} are supported.',
            )
          "
        >
          <template #quickActionsLink="{ content }">
            <gl-link :href="quickActionsHelpPath" target="_blank">{{ content }}</gl-link>
          </template>
          <template #markdownLink="{ content }">
            <gl-link :href="markdownHelpPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <p>
        <gl-sprintf
          :message="
            __(
              'This is a private email address %{helpIcon} generated just for you. Anyone who gets ahold of it can create issues or merge requests as if they were you. You should %{resetLinkStart}reset it%{resetLinkEnd} if that ever happens.',
            )
          "
        >
          <template #helpIcon>
            <gl-link :href="emailsHelpPagePath" target="_blank"
              ><gl-icon class="gl-text-blue-600" name="question-o"
            /></gl-link>
          </template>
          <template #resetLink="{ content }">
            <gl-button variant="link" @click="resetIncomingEmailToken">{{ content }}</gl-button>
          </template>
        </gl-sprintf>
      </p>
      <template #modal-footer>
        <gl-button category="secondary" @click="cancelHandler">{{ s__('Cancel') }}</gl-button>
      </template>
    </gl-modal>
  </div>
</template>
