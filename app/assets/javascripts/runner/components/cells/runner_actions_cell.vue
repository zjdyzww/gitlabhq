<script>
import { GlButton, GlButtonGroup, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import deleteRunnerMutation from '~/runner/graphql/delete_runner.mutation.graphql';
import updateRunnerMutation from '~/runner/graphql/update_runner.mutation.graphql';

const i18n = {
  I18N_EDIT: __('Edit'),
  I18N_PAUSE: __('Pause'),
  I18N_RESUME: __('Resume'),
  I18N_REMOVE: __('Remove'),
  I18N_REMOVE_CONFIRMATION: s__('Runners|Are you sure you want to delete this runner?'),
};

export default {
  components: {
    GlButton,
    GlButtonGroup,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    runner: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      updating: false,
      deleting: false,
    };
  },
  computed: {
    runnerNumericalId() {
      return getIdFromGraphQLId(this.runner.id);
    },
    runnerUrl() {
      // TODO implement using webUrl from the API
      return `${gon.gitlab_url || ''}/admin/runners/${this.runnerNumericalId}`;
    },
    isActive() {
      return this.runner.active;
    },
    toggleActiveIcon() {
      return this.isActive ? 'pause' : 'play';
    },
    toggleActiveTitle() {
      if (this.updating) {
        // Prevent a "sticky" tooltip: If this button is disabled,
        // mouseout listeners don't run leaving the tooltip stuck
        return '';
      }
      return this.isActive ? i18n.I18N_PAUSE : i18n.I18N_RESUME;
    },
    deleteTitle() {
      // Prevent a "sticky" tooltip: If element gets removed,
      // mouseout listeners don't run and leaving the tooltip stuck
      return this.deleting ? '' : i18n.I18N_REMOVE;
    },
  },
  methods: {
    async onToggleActive() {
      this.updating = true;
      // TODO In HAML iteration we had a confirmation modal via:
      //   data-confirm="_('Are you sure?')"
      // this may not have to ported, this is an easily reversible operation

      try {
        const toggledActive = !this.runner.active;

        const {
          data: {
            runnerUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateRunnerMutation,
          variables: {
            input: {
              id: this.runner.id,
              active: toggledActive,
            },
          },
        });

        if (errors && errors.length) {
          this.onError(new Error(errors[0]));
        }
      } catch (e) {
        this.onError(e);
      } finally {
        this.updating = false;
      }
    },

    async onDelete() {
      // TODO Replace confirmation with gl-modal
      // eslint-disable-next-line no-alert
      if (!window.confirm(i18n.I18N_REMOVE_CONFIRMATION)) {
        return;
      }

      this.deleting = true;
      try {
        const {
          data: {
            runnerDelete: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: deleteRunnerMutation,
          variables: {
            input: {
              id: this.runner.id,
            },
          },
          awaitRefetchQueries: true,
          refetchQueries: ['getRunners'],
        });
        if (errors && errors.length) {
          this.onError(new Error(errors[0]));
        }
      } catch (e) {
        this.onError(e);
      } finally {
        this.deleting = false;
      }
    },

    onError(error) {
      // TODO Render errors when "delete" action is done
      // `active` toggle would not fail due to user input.
      throw error;
    },
  },
  i18n,
};
</script>

<template>
  <gl-button-group>
    <gl-button
      v-gl-tooltip.hover.viewport
      :title="$options.i18n.I18N_EDIT"
      :aria-label="$options.i18n.I18N_EDIT"
      icon="pencil"
      :href="runnerUrl"
      data-testid="edit-runner"
    />
    <gl-button
      v-gl-tooltip.hover.viewport
      :title="toggleActiveTitle"
      :aria-label="toggleActiveTitle"
      :icon="toggleActiveIcon"
      :loading="updating"
      data-testid="toggle-active-runner"
      @click="onToggleActive"
    />
    <gl-button
      v-gl-tooltip.hover.viewport
      :title="deleteTitle"
      :aria-label="deleteTitle"
      icon="close"
      :loading="deleting"
      variant="danger"
      data-testid="delete-runner"
      @click="onDelete"
    />
  </gl-button-group>
</template>
