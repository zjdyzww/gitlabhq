<script>
import $ from 'jquery';
import { intersection } from 'lodash';

import '~/smart_interval';

import eventHub from '../../event_hub';
import Mediator from '../../sidebar_mediator';
import Store from '../../stores/sidebar_store';
import IssuableTimeTracker from './time_tracker.vue';

export default {
  components: {
    IssuableTimeTracker,
  },
  props: {
    issuableId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      mediator: new Mediator(),
      store: new Store(),
    };
  },
  mounted() {
    this.listenForQuickActions();
  },
  methods: {
    listenForQuickActions() {
      $(document).on('ajax:success', '.gfm-form', this.quickActionListened);

      eventHub.$on('timeTrackingUpdated', (data) => {
        this.quickActionListened({ detail: [data] });
      });
    },
    quickActionListened(e) {
      const data = e.detail[0];

      const subscribedCommands = ['spend_time', 'time_estimate'];
      let changedCommands;
      if (data !== undefined) {
        changedCommands = data.commands_changes ? Object.keys(data.commands_changes) : [];
      } else {
        changedCommands = [];
      }
      if (changedCommands && intersection(subscribedCommands, changedCommands).length) {
        this.mediator.fetch();
      }
    },
  },
};
</script>

<template>
  <div class="block">
    <issuable-time-tracker
      :issuable-id="issuableId"
      :time-estimate="store.timeEstimate"
      :time-spent="store.totalTimeSpent"
      :human-time-estimate="store.humanTimeEstimate"
      :human-time-spent="store.humanTotalTimeSpent"
      :limit-to-hours="store.timeTrackingLimitToHours"
    />
  </div>
</template>
